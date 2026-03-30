Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }
    return (Get-Location).Path
}

$repoRoot = Get-RepoRoot
Set-Location -LiteralPath $repoRoot

Write-Host "Stopping OpenClaw..."
& docker compose stop openclaw-gateway
if ($LASTEXITCODE -ne 0) {
    throw "Failed to stop OpenClaw."
}

Write-Host "OpenClaw is stopped."
