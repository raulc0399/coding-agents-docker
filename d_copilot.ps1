#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent (Resolve-Path $PSCommandPath)
. "$ScriptDir\lib\env_mounts.ps1"

$ComposeFile = "$ScriptDir\copilot\docker-compose.yml"
$HostWorkdir = (Get-Location).Path
$ProjectName = Split-Path $HostWorkdir -Leaf
$ContainerWorkdir = "/workspace/$ProjectName"

$EnvMounts   = Get-EnvNullMounts $HostWorkdir $ContainerWorkdir
$ConfigMount = Get-AgentConfigMountArgs "$HOME\.copilot" '/home/agent/.copilot'
$AgentArgs   = Get-AgentInstructionsArgs $HostWorkdir '/home/agent/.copilot/copilot-instructions.md'

$env:HOST_UID          = '1000'
$env:HOST_GID          = '1000'
$env:HOST_WORKDIR      = $HostWorkdir
$env:CONTAINER_WORKDIR = $ContainerWorkdir

docker compose -f $ComposeFile run --rm --name "d-copilot-$ProjectName" `
  @EnvMounts @ConfigMount @AgentArgs `
  copilot
