# Populates and returns -v /dev/null:<container-workdir>/<file>:ro flags for secret files found in $SrcDir

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

function Test-ContainerNameExists {
  param(
    [string]$Name
  )

  $existing = docker ps -a -q -f "name=^${Name}$"
  return -not [string]::IsNullOrWhiteSpace($existing)
}

# Resolves the container name to use, handling collisions; returns it.
function Resolve-ContainerName {
  param(
    [string]$Base
  )

  # Base name is free: use it as-is
  if (-not (Test-ContainerNameExists $Base)) { return $Base }

  # Pick the first free numeric suffix for the "start new" option
  $i = 1
  while (Test-ContainerNameExists "${Base}-${i}") { $i++ }
  $candidate = "${Base}-${i}"

  # Warn and ask how to proceed
  Write-Warning "A container named '${Base}' already exists."
  while ($true) {
    $answer = Read-Host "[k=kill prev / n=start new]"
    if ($answer -eq 'k' -or $answer -eq 'K') {
      docker rm -f $Base | Out-Null
      return $Base
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
