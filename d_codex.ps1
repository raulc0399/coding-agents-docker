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
$CodexConfigDir = if ([string]::IsNullOrEmpty($env:CODEX_CONFIG_DIR)) { "$HOME\.codex" } else { $env:CODEX_CONFIG_DIR }
$ConfigMount = Get-AgentConfigMountArgs $CodexConfigDir '/home/agent/.codex'
$AgentsMount = Get-AgentConfigMountArgs "$HOME\.agents" '/home/agent/.agents'
$AgentArgs   = Get-AgentInstructionsArgs $HostWorkdir '/home/agent/.codex/AGENTS.md'
$PortArgs    = @()
if (-not [string]::IsNullOrEmpty($env:CODEX_PORT)) {
  $PortArgs = @('-p', "$($env:CODEX_PORT):$($env:CODEX_PORT)")
}

$HostMcpToken = (Get-Content -Raw "$HOME\.config\mcp-runner\token").Trim()

$env:HOST_UID          = '1000'
$env:HOST_GID          = '1000'
$env:HOST_WORKDIR      = $HostWorkdir
$env:CONTAINER_WORKDIR = $ContainerWorkdir
$env:HOST_MCP_TOKEN    = $HostMcpToken

$ContainerName = Resolve-ContainerName "d-codex-$ProjectName"

docker compose -f $ComposeFile run --rm --name $ContainerName `
  @EnvMounts @ConfigMount @AgentsMount @AgentArgs @PortArgs `
  codex
