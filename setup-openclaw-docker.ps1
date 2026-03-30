Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $scriptPath = $MyInvocation.ScriptName
    if (-not $scriptPath) {
        throw "Unable to resolve script path."
    }
    return Split-Path -Parent $scriptPath
}

function Read-DotEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $values = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $values
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line.TrimStart().StartsWith("#")) {
            continue
        }
        $parts = $line -split "=", 2
        if ($parts.Count -ne 2) {
            continue
        }
        $values[$parts[0].Trim()] = $parts[1]
    }

    return $values
}

function Set-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Values,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $Values[$Key] = $Value
}

function Write-DotEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Values
    )

    $lines = foreach ($entry in $Values.GetEnumerator()) {
        "$($entry.Key)=$($entry.Value)"
    }
    [System.IO.File]::WriteAllLines($Path, $lines)
}

function Require-Setting {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Values,
        [Parameter(Mandatory = $true)]
        [string[]]$Keys,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    foreach ($key in $Keys) {
        if ($Values.Contains($key) -and -not [string]::IsNullOrWhiteSpace($Values[$key])) {
            return [string]$Values[$key]
        }
    }

    throw "Missing $Label in .env. Expected one of: $($Keys -join ', ')"
}

function Get-HexToken {
    param(
        [int]$Bytes = 32
    )

    $buffer = New-Object byte[] $Bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    return -join ($buffer | ForEach-Object { $_.ToString("x2") })
}

function To-ComposePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return ($Path -replace "\\", "/")
}

function Get-OpenRouterModel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Model
    )

    if ($Model.StartsWith("openrouter/")) {
        return $Model
    }

    return "openrouter/$Model"
}

function Invoke-DockerCompose {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & docker compose @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Invoke-Docker {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & docker @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$repoRoot = Get-RepoRoot
$dotenvPath = Join-Path $repoRoot ".env"
$dotenv = Read-DotEnv -Path $dotenvPath

$telegramBotToken = Require-Setting -Values $dotenv -Keys @("TELEGRAM_BOT_TOKEN", "BOT_TOKEN") -Label "Telegram bot token"
$openRouterApiKey = Require-Setting -Values $dotenv -Keys @("OPENROUTER_API_KEY", "OPENROUTER_KEY") -Label "OpenRouter API key"
$aiModelRaw = Require-Setting -Values $dotenv -Keys @("OPENCLAW_MODEL", "AI_MODEL") -Label "AI model"
$openClawModel = Get-OpenRouterModel -Model $aiModelRaw

$gatewayToken = if ($dotenv.Contains("OPENCLAW_GATEWAY_TOKEN") -and -not [string]::IsNullOrWhiteSpace($dotenv["OPENCLAW_GATEWAY_TOKEN"])) {
    [string]$dotenv["OPENCLAW_GATEWAY_TOKEN"]
}
else {
    Get-HexToken
}

$configDir = Join-Path $repoRoot ".openclaw"
$workspaceDir = Join-Path $repoRoot "workspace"
$dockerImage = if ($dotenv.Contains("OPENCLAW_IMAGE") -and -not [string]::IsNullOrWhiteSpace($dotenv["OPENCLAW_IMAGE"])) {
    [string]$dotenv["OPENCLAW_IMAGE"]
}
else {
    "ghcr.io/openclaw/openclaw:latest"
}

New-Item -ItemType Directory -Force -Path $configDir | Out-Null
New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null

Set-DotEnvValue -Values $dotenv -Key "TELEGRAM_BOT_TOKEN" -Value $telegramBotToken
Set-DotEnvValue -Values $dotenv -Key "OPENROUTER_API_KEY" -Value $openRouterApiKey
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_MODEL" -Value $openClawModel
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_GATEWAY_TOKEN" -Value $gatewayToken
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_CONFIG_DIR" -Value (To-ComposePath -Path $configDir)
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_WORKSPACE_DIR" -Value (To-ComposePath -Path $workspaceDir)
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_GATEWAY_PORT" -Value "18789"
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_BRIDGE_PORT" -Value "18790"
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_GATEWAY_BIND" -Value "lan"
Set-DotEnvValue -Values $dotenv -Key "OPENCLAW_IMAGE" -Value $dockerImage

Write-DotEnv -Path $dotenvPath -Values $dotenv

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker Desktop is not installed or docker.exe is not on PATH. Install/start Docker Desktop, reopen PowerShell, then rerun .\setup-openclaw-docker.ps1"
}

Write-Host "Using model: $openClawModel"
Write-Host "Docker image: $dockerImage"
Write-Host "Config dir:  $configDir"
Write-Host "Workspace:   $workspaceDir"
Write-Host ""
if ($dockerImage -eq "openclaw:local") {
    Write-Host "Building OpenClaw Docker image..."
    Invoke-Docker build -t "openclaw:local" -f "Dockerfile" "."
}
else {
    Write-Host "Pulling OpenClaw Docker image..."
    Invoke-Docker pull $dockerImage
}

Write-Host ""
Write-Host "Running non-interactive OpenClaw onboarding..."
Invoke-DockerCompose run --rm --no-deps --entrypoint node openclaw-gateway `
    dist/index.js onboard --non-interactive --mode local `
    --auth-choice openrouter-api-key `
    --openrouter-api-key $openRouterApiKey `
    --secret-input-mode plaintext `
    --gateway-auth token `
    --gateway-token $gatewayToken `
    --gateway-port 18789 `
    --gateway-bind lan `
    --skip-skills `
    --skip-health `
    --accept-risk

Write-Host ""
Write-Host "Pinning Docker gateway settings..."
$allowedOriginsJson = '["http://localhost:18789","http://127.0.0.1:18789"]'
$allowedOriginsCommand = "node dist/index.js config set gateway.controlUi.allowedOrigins '$allowedOriginsJson' --strict-json"
Invoke-DockerCompose run --rm --no-deps --entrypoint node openclaw-gateway `
    dist/index.js config set gateway.mode local
Invoke-DockerCompose run --rm --no-deps --entrypoint node openclaw-gateway `
    dist/index.js config set gateway.bind lan
Invoke-DockerCompose run --rm --no-deps --entrypoint sh openclaw-gateway `
    -lc $allowedOriginsCommand
Invoke-DockerCompose run --rm --no-deps --entrypoint node openclaw-gateway `
    dist/index.js config set agents.defaults.model.primary $openClawModel

Write-Host ""
Write-Host "Starting OpenClaw gateway..."
Invoke-DockerCompose up -d openclaw-gateway

Write-Host ""
Write-Host "Adding Telegram bot token..."
Invoke-DockerCompose run --rm openclaw-cli channels add --channel telegram --token $telegramBotToken

Write-Host ""
Write-Host "Dashboard link:"
Invoke-DockerCompose run --rm openclaw-cli dashboard --no-open

Write-Host ""
Write-Host "Setup complete."
Write-Host "Next:"
Write-Host "1. Open http://127.0.0.1:18789/"
Write-Host "2. Message your bot in Telegram."
Write-Host "3. Run: docker compose run --rm openclaw-cli pairing list telegram"
Write-Host "4. Approve the code with: docker compose run --rm openclaw-cli pairing approve telegram <CODE>"
