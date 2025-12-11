<#
.SYNOPSIS
    Pre-provisioning script for Azure deployment.

.DESCRIPTION
    This script performs pre-provisioning tasks including Docker validation and image building
    before Azure resources are provisioned. It validates Docker availability, checks for
    docker-compose configuration, and builds container images.

.PARAMETER Force
    Forces the build even if images already exist.

.PARAMETER SkipBuild
    Skips the Docker build step (validation only).

.EXAMPLE
    .\preprovision.ps1
    Runs standard pre-provisioning with default settings.

.EXAMPLE
    .\preprovision.ps1 -Force
    Forces rebuild of all Docker images.

.NOTES
    Author: Azure-LogicApps-Monitoring Team
    Version: 2.0
    Requires: Docker Desktop or Docker Engine
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Forces rebuild of Docker images")]
    [switch]$Force,

    [Parameter(HelpMessage = "Skips Docker build step")]
    [switch]$SkipBuild
)

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Functions

function Test-DockerAvailability {
    <#
    .SYNOPSIS
        Checks if Docker is available and running.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Write-Verbose "Checking Docker availability..."
        $dockerInfo = docker info 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Docker command executed but returned error code: $LASTEXITCODE"
            return $false
        }

        Write-Verbose "Docker is running successfully."
        return $true
    }
    catch {
        Write-Verbose "Docker check failed: $_"
        return $false
    }
}

function Test-DockerComposeFile {
    <#
    .SYNOPSIS
        Validates the existence of docker-compose configuration file.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]$Path = "docker-compose.yml"
    )

    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath "..\$Path" -Resolve -ErrorAction SilentlyContinue
    
    if (-not $fullPath) {
        $fullPath = Join-Path -Path (Get-Location) -ChildPath $Path
    }

    if (Test-Path -Path $fullPath -PathType Leaf) {
        Write-Verbose "Docker Compose file found at: $fullPath"
        return $true
    }

    Write-Warning "Docker Compose file not found at: $fullPath"
    return $false
}

function Invoke-DockerBuild {
    <#
    .SYNOPSIS
        Builds Docker images using Docker Compose.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [switch]$Force
    )

    try {
        $buildArgs = @('compose', 'build')
        
        if ($Force) {
            $buildArgs += '--no-cache'
            Write-Verbose "Building with --no-cache flag..."
        }

        Write-Host "Building Docker images..." -ForegroundColor Cyan
        
        # Use docker compose (v2) instead of docker-compose (v1)
        $output = & docker @buildArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker build failed with exit code $LASTEXITCODE. Output: $output"
            return $false
        }

        Write-Host "Docker images built successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to build Docker images: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Main Script

try {
    Write-Host "=== Pre-Provisioning Steps ===" -ForegroundColor Cyan
    Write-Host "Starting validation and build process..." -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Validate Docker availability
    Write-Host "[1/3] Validating Docker..." -ForegroundColor Yellow
    if (-not (Test-DockerAvailability)) {
        Write-Warning "Docker is not running or not installed."
        Write-Host "Please ensure Docker Desktop is installed and running." -ForegroundColor Yellow
        Write-Host "Skipping Docker build steps." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "✓ Docker is available and running" -ForegroundColor Green
    Write-Host ""

    # Step 2: Validate docker-compose.yml exists
    Write-Host "[2/3] Validating Docker Compose configuration..." -ForegroundColor Yellow
    if (-not (Test-DockerComposeFile)) {
        Write-Warning "docker-compose.yml not found in the project directory."
        Write-Host "Skipping Docker build steps." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "✓ Docker Compose configuration found" -ForegroundColor Green
    Write-Host ""

    # Step 3: Build Docker images (if not skipped)
    if ($SkipBuild) {
        Write-Host "[3/3] Skipping Docker build (SkipBuild flag set)" -ForegroundColor Yellow
    }
    else {
        Write-Host "[3/3] Building Docker images..." -ForegroundColor Yellow
        $buildSuccess = Invoke-DockerBuild -Force:$Force

        if (-not $buildSuccess) {
            Write-Error "Docker image build failed. Please review the errors above."
            exit 1
        }
        Write-Host "✓ Docker images built successfully" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== Pre-Provisioning Completed Successfully ===" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Pre-provisioning failed with error: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Cleanup or final steps if needed
    Write-Verbose "Pre-provisioning script completed."
}

#endregion