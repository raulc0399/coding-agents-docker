#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent (Resolve-Path $PSCommandPath)

docker compose -f "$ScriptDir\claude\docker-compose.yml" build --pull --no-cache
docker compose -f "$ScriptDir\codex\docker-compose.yml" build --pull --no-cache
docker compose -f "$ScriptDir\copilot\docker-compose.yml" build --pull --no-cache
