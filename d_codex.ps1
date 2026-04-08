#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent (Resolve-Path $PSCommandPath)
. "$ScriptDir\lib\env_mounts.ps1"

$ComposeFile = "$ScriptDir\codex\docker-compose.yml"
$HostWorkdir = (Get-Location).Path
$ProjectName = Split-Path $HostWorkdir -Leaf
$ContainerWorkdir = "/workspace/$ProjectName"

$EnvMounts   = Get-EnvNullMounts $HostWorkdir $ContainerWorkdir
$ConfigMount = Get-AgentConfigMountArgs "$HOME\.codex" '/home/agent/.codex'
$AgentArgs   = Get-AgentInstructionsArgs $HostWorkdir '/home/agent/.codex/AGENTS.md'

$env:HOST_UID          = '1000'
$env:HOST_GID          = '1000'
$env:HOST_WORKDIR      = $HostWorkdir
$env:CONTAINER_WORKDIR = $ContainerWorkdir

docker compose -f $ComposeFile run --rm --name "d-codex-$ProjectName" `
  @EnvMounts @ConfigMount @AgentArgs `
  codex
