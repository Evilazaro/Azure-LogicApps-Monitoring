#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Pre-provisioning script for Azure deployment.

.DESCRIPTION
    This script performs pre-provisioning tasks including Docker validation and image building
    before Azure resources are provisioned. It validates Docker availability, checks for
    docker-compose configuration, and builds container images.
    
    The script performs the following operations:
    - Validates Docker is installed and running
    - Checks for docker-compose.yml configuration file
    - Builds Docker images using Docker Compose

.PARAMETER Force
    Forces the build even if images already exist by using --no-cache flag.

.PARAMETER SkipBuild
    Skips the Docker build step (validation only).

.EXAMPLE
    .\preprovision.ps1
    Runs standard pre-provisioning with default settings.

.EXAMPLE
    .\preprovision.ps1 -Force
    Forces rebuild of all Docker images without using cache.

.EXAMPLE
    .\preprovision.ps1 -SkipBuild -Verbose
    Validates Docker availability without building images, with verbose output.

.NOTES
    File Name      : preprovision.ps1
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 2.0.0
    Last Modified  : 2025-12-17
    Requires       : Docker Desktop or Docker Engine
    Requires       : Docker Compose v2 (docker compose command)
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Forces rebuild of Docker images without using cache")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Skips Docker build step (validation only)")]
    [switch]$SkipBuild
)

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Script-level constants
$script:ScriptVersion = '2.0.0'

#region Functions

function Test-DockerAvailability {
    <#
    .SYNOPSIS
        Checks if Docker is available and running.
    
    .DESCRIPTION
        Validates that Docker is installed, accessible in PATH, and the Docker daemon is running.
        Returns $true if Docker is available and functional, $false otherwise.
    
    .OUTPUTS
        System.Boolean - Returns $true if Docker is available, $false otherwise.
    
    .EXAMPLE
        Test-DockerAvailability
        Returns $true if Docker is running, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose "Starting Docker availability check..."
    }

    process {
        try {
            # Check if docker command exists
            $dockerCommand = Get-Command -Name docker -ErrorAction SilentlyContinue
            if (-not $dockerCommand) {
                Write-Verbose "Docker command not found in PATH"
                return $false
            }
            
            Write-Verbose "Docker command found at: $($dockerCommand.Source)"
            
            # Test Docker daemon connectivity
            Write-Verbose "Testing Docker daemon connectivity..."
            $dockerInfo = & docker info 2>&1
            $dockerExitCode = $LASTEXITCODE
            
            if ($dockerExitCode -ne 0) {
                Write-Verbose "Docker info command failed with exit code: $dockerExitCode"
                Write-Verbose "Docker output: $($dockerInfo -join ' ')"
                return $false
            }

            Write-Verbose "Docker is running successfully"
            return $true
        }
        catch {
            Write-Verbose "Docker availability check failed: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-DockerComposeFile {
    <#
    .SYNOPSIS
        Validates the existence of docker-compose configuration file.
    
    .DESCRIPTION
        Checks if the docker-compose.yml file exists in the project root directory.
        Attempts to resolve the path relative to the script location first, then
        falls back to the current working directory.
    
    .PARAMETER Path
        The relative path to the docker-compose file. Defaults to 'docker-compose.yml'.
    
    .OUTPUTS
        System.Boolean - Returns $true if the file exists, $false otherwise.
    
    .EXAMPLE
        Test-DockerComposeFile
        Checks for docker-compose.yml in the default location.
    
    .EXAMPLE
        Test-DockerComposeFile -Path 'docker-compose.override.yml'
        Checks for a specific compose file.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = 'docker-compose.yml'
    )

    begin {
        Write-Verbose "Searching for Docker Compose file: $Path"
    }

    process {
        try {
            # Try to resolve relative to script root first
            $scriptRoot = $PSScriptRoot
            if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
                $scriptRoot = Get-Location
                Write-Verbose "PSScriptRoot is empty, using current location: $scriptRoot"
            }
            
            $fullPath = Join-Path -Path $scriptRoot -ChildPath '..'
            $fullPath = Join-Path -Path $fullPath -ChildPath $Path
            
            # Attempt to resolve to absolute path
            if (Test-Path -Path $fullPath -PathType Leaf) {
                $resolvedPath = [System.IO.Path]::GetFullPath($fullPath)
                Write-Verbose "Docker Compose file found at: $resolvedPath"
                return $true
            }
            
            # Fallback to current directory
            $fallbackPath = Join-Path -Path (Get-Location) -ChildPath $Path
            if (Test-Path -Path $fallbackPath -PathType Leaf) {
                Write-Verbose "Docker Compose file found at: $fallbackPath"
                return $true
            }

            Write-Verbose "Docker Compose file not found. Searched paths:"
            Write-Verbose "  - $fullPath"
            Write-Verbose "  - $fallbackPath"
            return $false
        }
        catch {
            Write-Verbose "Error checking Docker Compose file: $($_.Exception.Message)"
            return $false
        }
    }
}

function Invoke-DockerBuild {
    <#
    .SYNOPSIS
        Builds Docker images using Docker Compose.
    
    .DESCRIPTION
        Executes 'docker compose build' to build all services defined in docker-compose.yml.
        Supports forcing a clean build without cache and provides detailed output.
    
    .PARAMETER Force
        Forces a clean build by adding the --no-cache flag to docker compose build.
    
    .OUTPUTS
        System.Boolean - Returns $true if build succeeds, $false otherwise.
    
    .EXAMPLE
        Invoke-DockerBuild
        Builds Docker images using cache if available.
    
    .EXAMPLE
        Invoke-DockerBuild -Force
        Builds Docker images from scratch without using cache.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-Verbose "Preparing to build Docker images..."
    }

    process {
        try {
            $buildArgs = @('compose', 'build')
            
            if ($Force) {
                $buildArgs += '--no-cache'
                Write-Verbose "Using --no-cache flag for clean build"
            }
            
            $buildCommand = "docker $($buildArgs -join ' ')"
            
            if ($PSCmdlet.ShouldProcess('Docker images', 'Build')) {
                Write-Information "Building Docker images..."
                Write-Verbose "Executing: $buildCommand"
                
                # Execute docker compose build
                $output = & docker @buildArgs 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -ne 0) {
                    Write-Error "Docker build failed with exit code: $exitCode"
                    if ($output) {
                        Write-Error "Build output: $($output -join "`n")"
                    }
                    return $false
                }
                
                Write-Verbose "Docker build completed successfully"
                Write-Verbose "Build output: $($output -join "`n")"
                return $true
            }
            
            return $true
        }
        catch {
            Write-Error "Exception during Docker build: $($_.Exception.Message)" -ErrorAction Stop
            return $false
        }
    }
}

#endregion

#region Main Script Execution

try {
    # Start execution timer
    $executionStart = Get-Date
    
    Write-Information "══════════════════════════════════════════════════════════"
    Write-Information "Pre-Provisioning Script Started"
    Write-Information "══════════════════════════════════════════════════════════"
    Write-Information "Script Version: $script:ScriptVersion"
    Write-Information "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Information "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Information ""

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

    Write-Information ""
    Write-Information "══════════════════════════════════════════════════════════"
    Write-Information "Pre-Provisioning Completed Successfully!"
    Write-Information "══════════════════════════════════════════════════════════"
    
    $executionDuration = (New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds
    Write-Information "Duration: $([Math]::Round($executionDuration, 2)) seconds"
    Write-Verbose "Exiting with success code 0"
    
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