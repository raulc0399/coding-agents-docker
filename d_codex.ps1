#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent (Resolve-Path $PSCommandPath)
. "$ScriptDir\lib\env_mounts.ps1"

$ComposeFile = "$ScriptDir\codex\docker-compose.yml"
$HostNetworkComposeFile = "$ScriptDir\codex\docker-compose.host-network.yml"
$HostWorkdir = (Get-Location).Path
$ProjectName = Split-Path $HostWorkdir -Leaf
$ContainerWorkdir = "/workspace/$ProjectName"

$EnvMounts   = Get-EnvNullMounts $HostWorkdir $ContainerWorkdir
$CodexConfigDir = if ([string]::IsNullOrEmpty($env:CODEX_CONFIG_DIR)) { "$HOME\.codex" } else { $env:CODEX_CONFIG_DIR }
$ConfigMount = Get-AgentConfigMountArgs $CodexConfigDir '/home/agent/.codex'
$AzureConfigDir = if ([string]::IsNullOrEmpty($env:AZURE_CONFIG_DIR)) { "$HOME\.azure" } else { $env:AZURE_CONFIG_DIR }
$AzureMount = Get-AgentConfigMountArgs $AzureConfigDir '/home/agent/.azure'
$TerraformConfigDir = if ($env:APPDATA) { "$env:APPDATA\terraform.d" } else { "$HOME/.terraform.d" }
$TerraformConfigFile = if ($env:TF_CLI_CONFIG_FILE) { $env:TF_CLI_CONFIG_FILE } elseif ($env:APPDATA) { "$env:APPDATA\terraform.rc" } else { "$HOME/.terraformrc" }
$TerraformMount = Get-AgentConfigMountArgs $TerraformConfigDir '/home/agent/.terraform.d'
$TerraformConfigMount = Get-AgentConfigFileMountArgs $TerraformConfigFile '/home/agent/.terraformrc'
$AgentsMount = Get-AgentConfigMountArgs "$HOME\.agents" '/home/agent/.agents'
$AgentArgs   = Get-AgentInstructionsArgs $HostWorkdir '/home/agent/.codex/AGENTS.md'
$ComposeArgs = @('-f', $ComposeFile)
$PortArgs    = @()
if ($env:CODEX_HOST_NETWORK -eq 'true') {
  $ComposeArgs += @('-f', $HostNetworkComposeFile)
} elseif (-not [string]::IsNullOrEmpty($env:CODEX_PORT)) {
  $PortArgs = @('-p', "$($env:CODEX_PORT):$($env:CODEX_PORT)")
}

$HostMcpToken = Get-Content -Raw "$HOME\.config\mcp-runner\token"
if ($null -eq $HostMcpToken) { $HostMcpToken = "" }
$HostMcpToken = $HostMcpToken.Trim()

$env:HOST_UID          = '1000'
$env:HOST_GID          = '1000'
$env:HOST_WORKDIR      = $HostWorkdir
$env:CONTAINER_WORKDIR = $ContainerWorkdir
$env:HOST_MCP_TOKEN    = $HostMcpToken

$ContainerName = Resolve-ContainerName "d-codex-$ProjectName"

docker compose @ComposeArgs run --rm --name $ContainerName `
  @EnvMounts @ConfigMount @AzureMount @TerraformMount @TerraformConfigMount @AgentsMount @AgentArgs @PortArgs `
  codex
