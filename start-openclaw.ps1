Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }
    return (Get-Location).Path
}

function Test-DockerReady {
    & docker version --format "{{.Server.Version}}" *> $null
    return $LASTEXITCODE -eq 0
}

function Wait-DockerReady {
    param(
        [int]$TimeoutSeconds = 120
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-DockerReady) {
            return
        }
        Start-Sleep -Seconds 2
    }

    throw "Docker is not ready. Start Docker Desktop and try again."
}

function Ensure-DockerDesktop {
    if (Test-DockerReady) {
        return
    }

    $dockerDesktopExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path -LiteralPath $dockerDesktopExe) {
        Write-Host "Starting Docker Desktop..."
        Start-Process -FilePath $dockerDesktopExe | Out-Null
    }

    Write-Host "Waiting for Docker to become ready..."
    Wait-DockerReady
}

$repoRoot = Get-RepoRoot
Set-Location -LiteralPath $repoRoot

Ensure-DockerDesktop

Write-Host "Starting OpenClaw..."
& docker compose up -d openclaw-gateway
if ($LASTEXITCODE -ne 0) {
    throw "Failed to start OpenClaw."
}

Write-Host ""
Write-Host "OpenClaw is starting."
Write-Host "Dashboard: http://127.0.0.1:18789/"
Write-Host "Status command: docker compose ps"
