# Cambium Fiber Mock OLT - Windows Installer
# Usage: Invoke-WebRequest -Uri https://raw.githubusercontent.com/cmbmwifi/cambium-fiber-mock-olt/main/install.ps1 -OutFile install.ps1; .\install.ps1

param(
    [string]$InstallDir = "$env:ProgramData\Cambium\cambium-fiber-mock-olt"
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or newer (current: $($PSVersionTable.PSVersion))." -ForegroundColor Red
    Write-Host "Install PowerShell 7: https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows" -ForegroundColor Yellow
    exit 1
}

$RepoUrl = "https://github.com/cmbmwifi/cambium-fiber-mock-olt.git"
$ApiComposeDir = "$env:ProgramData\Cambium\cambium-fiber-api"

function Write-ColorOutput {
    param([string]$Message, [string]$Level = "INFO")
    switch ($Level) {
        "ERROR" { Write-Host "[$Level] $Message" -ForegroundColor Red }
        "WARN"  { Write-Host "[$Level] $Message" -ForegroundColor Yellow }
        default { Write-Host "[$Level] $Message" -ForegroundColor Cyan }
    }
}

Write-ColorOutput "Cambium Fiber Mock OLT Setup"

# --- Prerequisites ---
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "Docker is not installed." -Level ERROR
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "Git is not installed." -Level ERROR
    Write-ColorOutput "Install Git: https://git-scm.com/download/win" -Level INFO
    exit 1
}

$dockerVersion = docker version --format "{{.Server.Version}}" 2>$null
if (-not $dockerVersion) {
    Write-ColorOutput "Docker is not running. Start Docker Desktop first." -Level ERROR
    exit 1
}
Write-ColorOutput "Docker is ready (Docker version $dockerVersion)"

docker compose version 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Docker Compose is not available." -Level ERROR
    exit 1
}

# --- Check Cambium Fiber API is installed and running ---
if (-not (Test-Path "$ApiComposeDir\docker-compose.yml")) {
    Write-ColorOutput "Cambium Fiber API is not installed at $ApiComposeDir" -Level ERROR
    Write-ColorOutput "Install it first: https://github.com/cmbmwifi/cambium-fiber-api" -Level INFO
    exit 1
}

$apiContainer = docker inspect cambium-fiber-api 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Cambium Fiber API is installed but not running." -Level ERROR
    Write-ColorOutput "Start it first, then re-run this installer." -Level INFO
    exit 1
}
Write-ColorOutput "Cambium Fiber API detected"

# --- Create install directory ---
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-ColorOutput "Created $InstallDir"
}

# --- Clone or update repo ---
if (Test-Path "$InstallDir\.git") {
    Write-ColorOutput "Updating existing repo at $InstallDir"
    git -C $InstallDir pull --ff-only
    if ($LASTEXITCODE -ne 0) { Write-ColorOutput "Git pull failed" -Level ERROR; exit 1 }
} else {
    Write-ColorOutput "Cloning repo to $InstallDir"
    git clone $RepoUrl $InstallDir
    if ($LASTEXITCODE -ne 0) { Write-ColorOutput "Git clone failed" -Level ERROR; exit 1 }
}

# --- Detect API version and network ---
$ApiVersion = docker inspect cambium-fiber-api --format "{{index .Config.Labels `"org.opencontainers.image.version`"}}" 2>$null
if (-not $ApiVersion) {
    Write-ColorOutput "Could not detect API version from cambium-fiber-api image label." -Level ERROR
    Write-ColorOutput "Ensure the Cambium Fiber API container is running and properly tagged." -Level INFO
    exit 1
}

$ProjectName = "cambium-fiber-api_$($ApiVersion -replace '\.', '-')"
$ApiNetwork = "${ProjectName}_default"

Write-ColorOutput "Using API version: $ApiVersion"
Write-ColorOutput "Using API network: $ApiNetwork"

# --- Write .env file ---
@"
API_NETWORK=$ApiNetwork
COMPOSE_PROJECT_NAME=$ProjectName
API_VERSION=$ApiVersion
"@ | Set-Content -Path "$InstallDir\.env" -Encoding UTF8

# --- Start mock OLTs ---
Write-ColorOutput "Building and starting mock OLT containers..."
Push-Location $InstallDir
docker compose up -d --build
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Failed to start mock OLT containers" -Level ERROR
    Pop-Location
    exit 1
}
Pop-Location

Write-ColorOutput ""
Write-ColorOutput "================================================================"
Write-ColorOutput "  Mock OLT Setup Complete"
Write-ColorOutput "================================================================"
Write-ColorOutput ""
Write-ColorOutput "Open the Cambium Fiber API setup wizard and add these OLTs:"
Write-ColorOutput ""
Write-ColorOutput "   Hostname       HTTPS Port   SSH Port"
Write-ColorOutput "   mock-olt-631   443          22"
Write-ColorOutput "   mock-olt-632   443          22"
Write-ColorOutput "   mock-olt-633   443          22"
Write-ColorOutput "   mock-olt-634   443          22"
Write-ColorOutput "   mock-olt-635   443          22"
Write-ColorOutput "   mock-olt-636   443          22"
Write-ColorOutput ""
Write-ColorOutput "   Credential group -- Username: admin  Password: password"
Write-ColorOutput "================================================================"
