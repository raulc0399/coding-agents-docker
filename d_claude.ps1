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
$AzureConfigDir = if ($env:AZURE_CONFIG_DIR) { $env:AZURE_CONFIG_DIR } else { "$HOME\.azure" }
$AzureMount = Get-AgentConfigMountArgs $AzureConfigDir '/home/agent/.azure'
$TerraformConfigDir = if ($env:APPDATA) { "$env:APPDATA\terraform.d" } else { "$HOME/.terraform.d" }
$TerraformConfigFile = if ($env:TF_CLI_CONFIG_FILE) { $env:TF_CLI_CONFIG_FILE } elseif ($env:APPDATA) { "$env:APPDATA\terraform.rc" } else { "$HOME/.terraformrc" }
$TerraformMount = Get-AgentConfigMountArgs $TerraformConfigDir '/home/agent/.terraform.d'
$TerraformConfigMount = Get-AgentConfigFileMountArgs $TerraformConfigFile '/home/agent/.terraformrc'
$ConfigFileMount = Get-AgentConfigFileMountArgs $ClaudeConfigJson '/home/agent/.claude.json'
$AgentArgs    = Get-AgentInstructionsArgs $HostWorkdir '/home/agent/.claude/CLAUDE.md'

$HostMcpToken = Get-Content -Raw "$HOME\.config\mcp-runner\token"
if ($null -eq $HostMcpToken) { $HostMcpToken = "" }
$HostMcpToken = $HostMcpToken.Trim()

$env:HOST_UID          = '1000'
$env:HOST_GID          = '1000'
$env:HOST_WORKDIR      = $HostWorkdir
$env:CONTAINER_WORKDIR = $ContainerWorkdir
$env:HOST_MCP_TOKEN    = $HostMcpToken

$ContainerName = Resolve-ContainerName "d-claude-$ProjectName"

docker compose -f $ComposeFile run --rm --name $ContainerName `
  @EnvMounts @ConfigMount @AzureMount @TerraformMount @TerraformConfigMount @ConfigFileMount @AgentArgs `
  claude
