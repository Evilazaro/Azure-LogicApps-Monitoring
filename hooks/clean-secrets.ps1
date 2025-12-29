#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Clears .NET user secrets for all projects in the solution.

.DESCRIPTION
    This script clears all .NET user secrets from the configured projects to ensure
    a clean state. This is useful before re-provisioning or when troubleshooting
    configuration issues.
    
    The script performs the following operations:
    - Validates .NET SDK availability
    - Clears user secrets for app.AppHost project
    - Clears user secrets for eShop.Orders.API project
    - Clears user secrets for eShop.Web.App project
    - Provides detailed logging and error handling

.PARAMETER Force
    Skips confirmation prompts and forces execution.

.PARAMETER WhatIf
    Common parameter (because SupportsShouldProcess is enabled).
    Shows what would be executed without making changes.

.EXAMPLE
    .\clean-secrets.ps1
    Clears all user secrets with confirmation prompt.

.EXAMPLE
    .\clean-secrets.ps1 -Force
    Clears all user secrets without confirmation.

.EXAMPLE
    .\clean-secrets.ps1 -WhatIf -Verbose
    Shows what would be cleared without making changes, with verbose output.

.NOTES
    File Name      : clean-secrets.ps1
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 2.0.1
    Last Modified  : 2025-12-29
    Prerequisite   : .NET SDK 10.0 or higher
    Copyright      : (c) 2025. All rights reserved.

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Skip confirmation prompts')]
    [switch]$Force
)

#Requires -Version 7.0

# Script configuration
Set-StrictMode -Version Latest
$script:OriginalErrorActionPreference = $ErrorActionPreference
$script:OriginalInformationPreference = $InformationPreference
$script:OriginalProgressPreference = $ProgressPreference
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Script-level constants
$script:ScriptVersion = '2.0.1'
$script:MinimumDotNetMajorVersion = 10
$script:Projects = @(
    @{
        Name = 'app.AppHost'
        Path = Join-Path $PSScriptRoot '..\app.AppHost\'
    },
    @{
        Name = 'eShop.Orders.API'
        Path = Join-Path $PSScriptRoot '..\src\eShop.Orders.API\'
    },
    @{
        Name = 'eShop.Web.App'
        Path = Join-Path $PSScriptRoot '..\src\eShop.Web.App\'
    }
)

#region Functions

function Test-DotNetAvailability {
    <#
    .SYNOPSIS
        Checks if .NET SDK is available.
    
    .DESCRIPTION
        Validates that .NET SDK is installed and accessible in PATH.
        Returns an object describing whether .NET is available and meets the minimum version.
    
    .OUTPUTS
        System.Management.Automation.PSCustomObject - Availability and version details.
    
    .EXAMPLE
        Test-DotNetAvailability
        Returns an object indicating availability, version, and failure reason.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    begin {
        Write-Verbose 'Starting .NET SDK availability check...'
    }

    process {
        try {
            $dotnetCommand = Get-Command -Name dotnet -ErrorAction SilentlyContinue
            if (-not $dotnetCommand) {
                Write-Verbose '.NET command not found in PATH'
                return [pscustomobject]@{
                    IsAvailable = $false
                    Version     = $null
                    Reason      = 'dotnet command not found in PATH'
                }
            }
            
            Write-Verbose "dotnet command found at: $($dotnetCommand.Source)"
            
            # Verify dotnet can execute
            $dotnetVersion = & dotnet --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose 'dotnet command failed to execute'
                return [pscustomobject]@{
                    IsAvailable = $false
                    Version     = $null
                    Reason      = 'dotnet command failed to execute'
                }
            }

            $dotnetVersion = ($dotnetVersion | Select-Object -First 1).ToString().Trim()
            if ([string]::IsNullOrWhiteSpace($dotnetVersion)) {
                return [pscustomobject]@{
                    IsAvailable = $false
                    Version     = $null
                    Reason      = 'dotnet --version returned empty output'
                }
            }

            $majorString = ($dotnetVersion -split '\.')[0]
            $major = 0
            if (-not [int]::TryParse($majorString, [ref]$major)) {
                return [pscustomobject]@{
                    IsAvailable = $false
                    Version     = $dotnetVersion
                    Reason      = 'Unable to parse dotnet major version'
                }
            }

            if ($major -lt $script:MinimumDotNetMajorVersion) {
                return [pscustomobject]@{
                    IsAvailable = $false
                    Version     = $dotnetVersion
                    Reason      = "dotnet SDK major version $major is less than required $script:MinimumDotNetMajorVersion"
                }
            }
            
            Write-Verbose '.NET SDK is available and functional'
            return [pscustomobject]@{
                IsAvailable = $true
                Version     = $dotnetVersion
                Reason      = $null
            }
        }
        catch {
            Write-Verbose "Error checking .NET availability: $($_.Exception.Message)"
            return [pscustomobject]@{
                IsAvailable = $false
                Version     = $null
                Reason      = $_.Exception.Message
            }
        }
    }
}

function Test-ProjectPath {
    <#
    .SYNOPSIS
        Validates that a project path exists.
    
    .DESCRIPTION
        Checks if the specified project directory exists and contains a project file.
    
    .PARAMETER Path
        The path to validate.
    
    .PARAMETER Name
        The project name for logging purposes.
    
    .OUTPUTS
        System.String - Returns the full path to the project file if found; otherwise, $null.
    
    .EXAMPLE
        Test-ProjectPath -Path '.\app.AppHost\' -Name 'app.AppHost'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    begin {
        Write-Verbose "Validating project path for: $Name"
    }

    process {
        try {
            $resolvedPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
            if (-not $resolvedPath) {
                Write-Warning "Project path not found: $Path"
                return $null
            }

            $resolvedDirectory = ($resolvedPath | Select-Object -First 1).Path
            
            # Check if directory contains a .csproj file
            $projectFiles = @(Get-ChildItem -Path $resolvedDirectory -Filter '*.csproj' -File -ErrorAction SilentlyContinue)
            if ($projectFiles.Count -eq 0) {
                Write-Warning "No .csproj file found in: $Path"
                return $null
            }

            if ($projectFiles.Count -gt 1) {
                Write-Warning "Multiple .csproj files found in: $resolvedDirectory. Using first match: $($projectFiles[0].Name)"
            }
            
            Write-Verbose "Project path validated: $resolvedDirectory"
            return $projectFiles[0].FullName
        }
        catch {
            Write-Warning "Error validating project path ${Path}: $($_.Exception.Message)"
            return $null
        }
    }
}

function Clear-ProjectUserSecrets {
    <#
    .SYNOPSIS
        Clears user secrets for a specific project.
    
    .DESCRIPTION
        Executes 'dotnet user-secrets clear' for the specified project file.
        Handles errors gracefully and provides detailed logging.
    
    .PARAMETER ProjectPath
        The path to the project (.csproj) file.
    
    .PARAMETER ProjectName
        The project name for logging purposes.
    
    .OUTPUTS
        System.Boolean - Returns $true if successful, $false otherwise.
    
    .EXAMPLE
        Clear-ProjectUserSecrets -ProjectPath '.\app.AppHost\app.AppHost.csproj' -ProjectName 'app.AppHost'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectPath,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectName
    )

    begin {
        Write-Verbose "Preparing to clear user secrets for: $ProjectName"
    }

    process {
        try {
            if (-not (Test-Path -LiteralPath $ProjectPath -PathType Leaf)) {
                Write-Warning "Project file not found for ${ProjectName}: $ProjectPath"
                return $false
            }

            if ($PSCmdlet.ShouldProcess($ProjectName, 'Clear user secrets')) {
                Write-Information "Clearing user secrets for project: $ProjectName"
                
                # Execute dotnet user-secrets clear
                $output = & dotnet user-secrets clear --project $ProjectPath 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Information "✓ Successfully cleared user secrets for: $ProjectName"
                    Write-Verbose "Output: $output"
                    return $true
                }
                else {
                    Write-Warning "Failed to clear user secrets for ${ProjectName}. Exit code: $LASTEXITCODE"
                    Write-Verbose "Error output: $output"
                    return $false
                }
            }
            else {
                Write-Verbose "WhatIf: Would clear user secrets for $ProjectName"
                return $true
            }
        }
        catch {
            Write-Error "Error clearing user secrets for ${ProjectName}: $($_.Exception.Message)"
            return $false
        }
    }
}

function Write-ScriptHeader {
    <#
    .SYNOPSIS
        Displays the script header with version information.
    
    .DESCRIPTION
        Outputs a formatted header with script name, version, and execution details.
    
    .EXAMPLE
        Write-ScriptHeader
    #>
    [CmdletBinding()]
    param()

    process {
        Write-Information ''
        Write-Information '================================================================='
        Write-Information "  Clean .NET User Secrets - Version $script:ScriptVersion"
        Write-Information '  Azure Logic Apps Monitoring Project'
        Write-Information '================================================================='
        Write-Information ''
    }
}

function Write-ScriptSummary {
    <#
    .SYNOPSIS
        Displays the execution summary.
    
    .DESCRIPTION
        Outputs a summary of the script execution results.
    
    .PARAMETER SuccessCount
        Number of successful operations.
    
    .PARAMETER FailureCount
        Number of failed operations.
    
    .PARAMETER TotalCount
        Total number of operations.
    
    .EXAMPLE
        Write-ScriptSummary -SuccessCount 3 -FailureCount 0 -TotalCount 3
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SuccessCount,
        
        [Parameter(Mandatory = $true)]
        [int]$FailureCount,
        
        [Parameter(Mandatory = $true)]
        [int]$TotalCount
    )

    process {
        Write-Information ''
        Write-Information '================================================================='
        Write-Information '  Execution Summary'
        Write-Information '================================================================='
        Write-Information "  Total projects:      $TotalCount"
        Write-Information "  Successfully cleared: $SuccessCount"
        Write-Information "  Failed:              $FailureCount"
        Write-Information '================================================================='
        Write-Information ''
    }
}

#endregion

#region Main Execution

try {
    # Display script header
    Write-ScriptHeader
    
    # Step 1: Validate .NET SDK availability
    Write-Information 'Step 1: Validating .NET SDK availability...'
    $dotnetCheck = Test-DotNetAvailability
    if (-not $dotnetCheck.IsAvailable) {
        $reason = if ($dotnetCheck.Reason) { $dotnetCheck.Reason } else { 'Unknown reason' }
        throw ".NET SDK is not installed, not accessible, or does not meet requirements. Required: .NET SDK $script:MinimumDotNetMajorVersion.0 or higher. Details: $reason"
    }
    Write-Information "✓ .NET SDK is available (version: $($dotnetCheck.Version))"
    Write-Information ''
    
    # Step 2: Validate project paths
    Write-Information 'Step 2: Validating project paths...'
    $validProjects = [System.Collections.Generic.List[hashtable]]::new()
    
    foreach ($project in $script:Projects) {
        $projectFile = Test-ProjectPath -Path $project.Path -Name $project.Name
        if ($projectFile) {
            $validProjects.Add(@{
                Name = $project.Name
                Path = $project.Path
                ProjectFile = $projectFile
            })
            Write-Information "  ✓ $($project.Name)"
        }
        else {
            Write-Warning "  ✗ $($project.Name) - Path not found or invalid"
        }
    }
    
    if ($validProjects.Count -eq 0) {
        throw 'No valid project paths found. Please ensure the repository structure is intact and the expected project folders exist relative to this script.'
    }
    
    Write-Information ''
    Write-Information "Found $($validProjects.Count) valid project(s)"
    Write-Information ''
    
    # Respect PowerShell native confirmation model; -Force disables confirmation prompts.
    if ($Force) {
        $ConfirmPreference = 'None'
    }
    
    # Step 4: Clear user secrets
    Write-Information 'Step 3: Clearing user secrets...'
    Write-Information ''
    
    $successCount = 0
    $failureCount = 0
    
    foreach ($project in $validProjects) {
        $result = Clear-ProjectUserSecrets -ProjectPath $project.ProjectFile -ProjectName $project.Name
        if ($result) {
            $successCount++
        }
        else {
            $failureCount++
        }
    }
    
    # Display summary
    Write-ScriptSummary -SuccessCount $successCount -FailureCount $failureCount -TotalCount $validProjects.Count
    
    # Exit with appropriate code
    if ($failureCount -gt 0) {
        Write-Warning 'Script completed with errors.'
        exit 1
    }
    else {
        Write-Information 'Script completed successfully.'
        exit 0
    }
}
catch {
    Write-Error "Fatal error: $($_.Exception.Message)"
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Reset preferences
    $ErrorActionPreference = $script:OriginalErrorActionPreference
    $InformationPreference = $script:OriginalInformationPreference
    $ProgressPreference = $script:OriginalProgressPreference
}

#endregion