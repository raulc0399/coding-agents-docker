#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent (Resolve-Path $PSCommandPath)
. "$ScriptDir\lib\env_mounts.ps1"

$ComposeFile = "$ScriptDir\claude\docker-compose.yml"
$HostWorkdir = (Get-Location).Path
$ProjectName = Split-Path $HostWorkdir -Leaf
$ContainerWorkdir = "/workspace/$ProjectName"

$ClaudeConfigDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { "$HOME\.claude" }
$ClaudeConfigJson = if ($env:CLAUDE_CONFIG_JSON) { $env:CLAUDE_CONFIG_JSON } else { "$HOME\.claude.json" }

$EnvMounts    = Get-EnvNullMounts $HostWorkdir $ContainerWorkdir
$ConfigMount  = Get-AgentConfigMountArgs $ClaudeConfigDir '/home/agent/.claude'
$ConfigFileMount = Get-AgentConfigFileMountArgs $ClaudeConfigJson '/home/agent/.claude.json'
$AgentArgs    = Get-AgentInstructionsArgs $HostWorkdir '/home/agent/.claude/CLAUDE.md'

$env:HOST_UID          = '1000'
$env:HOST_GID          = '1000'
$env:HOST_WORKDIR      = $HostWorkdir
$env:CONTAINER_WORKDIR = $ContainerWorkdir

docker compose -f $ComposeFile run --rm --name "d-claude-$ProjectName" `
  @EnvMounts @ConfigMount @ConfigFileMount @AgentArgs `
  claude
