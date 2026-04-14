# Cambium Fiber Mock OLT - Windows Uninstaller

param(
    [string]$InstallDir = "$env:ProgramData\Cambium\cambium-fiber-mock-olt"
)

function Write-ColorOutput {
    param([string]$Message, [string]$Level = "INFO")
    switch ($Level) {
        "ERROR" { Write-Host "[$Level] $Message" -ForegroundColor Red }
        "WARN"  { Write-Host "[$Level] $Message" -ForegroundColor Yellow }
        default { Write-Host "[$Level] $Message" -ForegroundColor Cyan }
    }
}

Write-ColorOutput "Cambium Fiber Mock OLT Uninstall"

if (Test-Path $InstallDir) {
    Write-ColorOutput "Removing mock OLT containers, images, and volumes"
    Push-Location $InstallDir
    docker compose down --rmi all --volumes 2>$null
    Pop-Location

    Write-ColorOutput "Removing $InstallDir"
    Remove-Item -Recurse -Force $InstallDir
} else {
    Write-ColorOutput "$InstallDir not found — stopping containers by project name"
    $Project = docker ps --filter "name=cambium-fiber-api-mock-olt" --format "{{.Label `"com.docker.compose.project`"}}" 2>$null | Select-Object -First 1
    if ($Project) {
        docker compose -p $Project down --rmi all --volumes
    } else {
        Write-ColorOutput "Could not detect running mock OLT project — nothing removed" -Level WARN
    }
}

Write-ColorOutput "Uninstall complete"
