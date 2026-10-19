# Populates and returns -v /dev/null:<container-workdir>/<file>:ro flags for secret files found in $SrcDir

$AGENT_CONTAINER_LABEL = 'coding-agents.agent'
$AGENT_WORKDIR_LABEL = 'coding-agents.workdir'

$SECRET_FILE_NAMES = @(
  '.env', '.envrc', '.npmrc', '.yarnrc', '.yarnrc.yml',
  '.pypirc', 'pip.conf', 'auth.json', '.pnpmfile.cjs',
  '.sentryclirc', '.vercelrc'
)

function Get-EnvNullMounts {
  param(
    [string]$SrcDir,
    [string]$ContainerWorkdir = '/workspace'
  )

  $mounts = @()

  $files = Get-ChildItem -LiteralPath $SrcDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -in $SECRET_FILE_NAMES -or $_.Name -like '.env.*'
    }

  foreach ($file in $files) {
    $rel = $file.FullName.Substring($SrcDir.Length).TrimStart('\', '/')
    $rel = $rel -replace '\\', '/'
    $mounts += '-v'
    $mounts += "/dev/null:${ContainerWorkdir}/${rel}:ro"
  }

  # Per-project overrides: each line in .nullmounts is an additional path to mask
  $nullmountsFile = Join-Path $SrcDir '.nullmounts'
  if (Test-Path $nullmountsFile) {
    foreach ($line in Get-Content $nullmountsFile) {
      if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
      $mounts += '-v'
      $mounts += "/dev/null:${ContainerWorkdir}/${line}:ro"
    }
  }

  return $mounts
}

function Get-AgentInstructionsArgs {
  param(
    [string]$SrcDir,
    [string]$ContainerPath
  )

  $hostPath = Resolve-AgentInstructionsPath $SrcDir
  if ($null -eq $hostPath) { return @() }

  return @('-v', "${hostPath}:${ContainerPath}:ro")
}

function Get-AgentConfigMountArgs {
  param(
    [string]$HostDir,
    [string]$ContainerDir
  )

  $HostDir = $HostDir -replace '^~', $HOME
  if (-not (Test-Path $HostDir)) { New-Item -ItemType Directory -Path $HostDir -Force | Out-Null }

  return @('-v', "${HostDir}:${ContainerDir}")
}

function Get-AgentConfigFileMountArgs {
  param(
    [string]$HostFile,
    [string]$ContainerFile
  )

  $HostFile = $HostFile -replace '^~', $HOME
  $dir = Split-Path $HostFile -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (-not (Test-Path $HostFile)) { New-Item -ItemType File -Path $HostFile -Force | Out-Null }

  return @('-v', "${HostFile}:${ContainerFile}")
}

function Find-AgentContainer {
  param(
    [string]$Agent,
    [string]$Workdir
  )

  $containers = docker ps --format '{{.Names}}' `
    --filter "label=${AGENT_CONTAINER_LABEL}=${Agent}" `
    --filter "label=${AGENT_WORKDIR_LABEL}=${Workdir}"
  if ($LASTEXITCODE -ne 0) { throw "docker ps failed" }

  $first = @($containers) | Select-Object -First 1
  if ($null -eq $first) { return '' }
  return [string]$first
}

# Stops the container once the agent's tmux session has ended; a detached session keeps it running.
function Stop-AgentContainerIfDone {
  param(
    [string]$Container,
    [string]$Session
  )

  # Native stderr must not become a terminating error here
  $ErrorActionPreference = 'Continue'

  docker exec $Container tmux has-session -t "=${Session}" 2>$null
  if ($LASTEXITCODE -eq 0) { return }

  docker stop $Container 2>$null | Out-Null
}

function Test-ContainerNameExists {
  param(
    [string]$Name
  )

  $existing = docker ps -a -q -f "name=^${Name}$"
  return -not [string]::IsNullOrWhiteSpace($existing)
}

# Resolves the container name to use, handling collisions; returns it.
# Optional $Running is a running container for this project that can be attached to; $Attach is set to $true when chosen.
function Resolve-ContainerName {
  param(
    [string]$Base,
    [string]$Running = '',
    [ref]$Attach
  )

  $prev = if ($Running) { $Running } else { $Base }
  if ($Attach) { $Attach.Value = $false }

  # Base name is free and nothing to attach to: use it as-is
  if (-not $Running -and -not (Test-ContainerNameExists $Base)) { return $Base }

  # Pick the first free numeric suffix for the "start new" option
  $i = 1
  while (Test-ContainerNameExists "${Base}-${i}") { $i++ }
  $candidate = "${Base}-${i}"

  # Warn and ask how to proceed
  Write-Warning "A container named '${prev}' already exists."
  $options = 'k=kill prev / n=start new'
  if ($Running) { $options = "a=attach / ${options}" }

  while ($true) {
    $answer = Read-Host "[${options}]"
    if ($Running -and ($answer -eq 'a' -or $answer -eq 'A')) {
      $Attach.Value = $true
      return $Running
    }
    if ($answer -eq 'k' -or $answer -eq 'K') {
      docker rm -f $prev | Out-Null
      return $prev
    }
    if ($answer -eq 'n' -or $answer -eq 'N') {
      return $candidate
    }
  }
}

function Resolve-AgentInstructionsPath {
  param(
    [string]$SrcDir
  )

  $hostPath = $env:AGENTS_MD_PATH
  if ([string]::IsNullOrEmpty($hostPath)) { return $null }

  $hostPath = $hostPath -replace '^~', $HOME

  if (-not [System.IO.Path]::IsPathRooted($hostPath)) {
    $hostPath = Join-Path $SrcDir $hostPath
  }

  if (-not (Test-Path $hostPath)) {
    Write-Error "AGENTS_MD_PATH file not found: ${hostPath}"
    exit 1
  }

  return $hostPath
}
