#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Configures federated identity credentials for GitHub Actions OIDC authentication.

.DESCRIPTION
    This script adds or updates federated identity credentials in an Azure AD App Registration
    to enable GitHub Actions workflows to authenticate using OpenID Connect (OIDC) without
    storing secrets.

    The script performs the following operations:
    - Verifies Azure CLI login status
    - Retrieves or looks up the target App Registration by name or Object ID
    - Lists existing federated credentials for the App Registration
    - Creates a new federated credential for the specified GitHub environment
    - Optionally creates additional credentials for the main branch and pull requests

    This script is designed to be run as an Azure Developer CLI (azd) hook, where environment
    variables are automatically loaded during the provisioning process. It can also be run
    standalone with the required parameters.

.PARAMETER AppName
    The display name of the Azure AD App Registration. If not provided and AppObjectId is also
    not specified, the script will list available App Registrations and prompt for selection.

.PARAMETER AppObjectId
    The Object ID of the Azure AD App Registration. If provided, this takes precedence over AppName
    and skips the lookup process.

.PARAMETER GitHubOrg
    The GitHub organization or username that owns the repository. Default: Evilazaro

.PARAMETER GitHubRepo
    The GitHub repository name for which to configure OIDC authentication. Default: Azure-LogicApps-Monitoring

.PARAMETER Environment
    The GitHub Environment name to configure for OIDC. This creates a subject claim in the format
    'repo:{org}/{repo}:environment:{environment}'. Default: dev

.EXAMPLE
    ./configure-federated-credential.ps1 -AppName 'my-app-registration'

    Configures a federated credential for the 'dev' environment using the specified App Registration name.

.EXAMPLE
    ./configure-federated-credential.ps1 -AppObjectId '00000000-0000-0000-0000-000000000000' -Environment 'prod'

    Configures a federated credential for the 'prod' environment using the App Registration Object ID.

.EXAMPLE
    ./configure-federated-credential.ps1 -AppName 'my-app' -GitHubOrg 'MyOrg' -GitHubRepo 'MyRepo' -Environment 'staging'

    Configures a federated credential for a custom GitHub organization, repository, and environment.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    None. This script writes status messages to the host but does not return objects.

.NOTES
    Author: Azure Developer CLI Hook
    Requires: Azure CLI, PowerShell 7.0+

.LINK
    https://docs.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation

.LINK
    https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$AppName,

    [Parameter(Mandatory = $false)]
    [string]$AppObjectId,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg = 'Evilazaro',

    [Parameter(Mandatory = $false)]
    [string]$GitHubRepo = 'Azure-LogicApps-Monitoring',

    [Parameter(Mandatory = $false)]
    [string]$Environment = 'dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Store original preferences to restore in finally block
$script:OriginalErrorActionPreference = $ErrorActionPreference

#region Constants
$script:GITHUB_OIDC_ISSUER = 'https://token.actions.githubusercontent.com'
$script:AZURE_AD_AUDIENCE = 'api://AzureADTokenExchange'
#endregion Constants

#region Helper Functions
function Write-InfoMessage {
    <#
    .SYNOPSIS
        Writes an informational message to the host.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a formatted section header.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
}

function Test-AzureCliLogin {
    <#
    .SYNOPSIS
        Verifies Azure CLI login status.
    .OUTPUTS
        PSCustomObject containing the account information if logged in.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    Write-InfoMessage -Message "`nChecking Azure CLI login status..." -ForegroundColor Yellow

    try {
        $accountJson = az account show --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw 'Not logged in to Azure CLI'
        }
        $account = $accountJson | ConvertFrom-Json
        Write-InfoMessage -Message "Logged in as: $($account.user.name)" -ForegroundColor Green
        Write-InfoMessage -Message "Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
        return $account
    }
    catch {
        Write-InfoMessage -Message "Not logged in to Azure CLI. Please run 'az login' first." -ForegroundColor Red
        exit 1
    }
}

function Get-AppRegistration {
    <#
    .SYNOPSIS
        Retrieves the App Registration by name or Object ID.
    .OUTPUTS
        PSCustomObject containing the app registration details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$ObjectId
    )

    if (-not [string]::IsNullOrWhiteSpace($ObjectId)) {
        return [PSCustomObject]@{ id = $ObjectId }
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-InfoMessage -Message "`nNo AppName or AppObjectId provided. Listing available App Registrations..." -ForegroundColor Yellow

        $appsJson = az ad app list --all --query "[].{DisplayName:displayName, AppId:appId, ObjectId:id}" --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-InfoMessage -Message 'Failed to list App Registrations.' -ForegroundColor Red
            exit 1
        }

        $apps = $appsJson | ConvertFrom-Json

        if ($null -eq $apps -or $apps.Count -eq 0) {
            Write-InfoMessage -Message 'No App Registrations found in this tenant.' -ForegroundColor Red
            exit 1
        }

        Write-InfoMessage -Message "`nAvailable App Registrations:" -ForegroundColor Cyan
        $apps | Format-Table -AutoSize

        $Name = Read-Host 'Enter the App Registration display name'
    }

    Write-InfoMessage -Message "`nLooking up App Registration: $Name" -ForegroundColor Yellow

    $appJson = az ad app list --display-name $Name --query '[0]' --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-InfoMessage -Message "Failed to look up App Registration '$Name'." -ForegroundColor Red
        exit 1
    }

    $app = $appJson | ConvertFrom-Json

    if ($null -eq $app) {
        Write-InfoMessage -Message "App Registration '$Name' not found." -ForegroundColor Red
        exit 1
    }

    Write-InfoMessage -Message 'Found App Registration:' -ForegroundColor Green
    Write-InfoMessage -Message "  Display Name: $($app.displayName)"
    Write-InfoMessage -Message "  App ID (Client ID): $($app.appId)"
    Write-InfoMessage -Message "  Object ID: $($app.id)"

    return $app
}

function Get-FederatedCredentials {
    <#
    .SYNOPSIS
        Retrieves existing federated credentials for an app.
    .OUTPUTS
        Array of federated credential objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppObjectId
    )

    Write-InfoMessage -Message "`nChecking existing federated credentials..." -ForegroundColor Yellow

    try {
        $credentialsJson = az ad app federated-credential list --id $AppObjectId --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            return @()
        }
        $credentials = $credentialsJson | ConvertFrom-Json
        return $credentials
    }
    catch {
        return @()
    }
}

function New-FederatedCredential {
    <#
    .SYNOPSIS
        Creates a new federated credential for an app.
    .OUTPUTS
        PSCustomObject containing the created credential.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppObjectId,

        [Parameter(Mandatory = $true)]
        [string]$CredentialName,

        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ($PSCmdlet.ShouldProcess($CredentialName, 'Create federated credential')) {
        Write-InfoMessage -Message "`nCreating federated credential..." -ForegroundColor Yellow
        Write-InfoMessage -Message "  Name: $CredentialName"
        Write-InfoMessage -Message "  Issuer: $script:GITHUB_OIDC_ISSUER"
        Write-InfoMessage -Message "  Subject: $Subject"
        Write-InfoMessage -Message "  Audience: $script:AZURE_AD_AUDIENCE"

        $credentialParams = @{
            name        = $CredentialName
            issuer      = $script:GITHUB_OIDC_ISSUER
            subject     = $Subject
            audiences   = @($script:AZURE_AD_AUDIENCE)
            description = $Description
        }

        # Create a temporary file for the JSON parameters
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            $credentialParams | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8

            $resultJson = az ad app federated-credential create --id $AppObjectId --parameters "@$tempFile" --output json 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Azure CLI returned error: $resultJson"
            }

            $result = $resultJson | ConvertFrom-Json
            Write-InfoMessage -Message "`nFederated credential created successfully!" -ForegroundColor Green
            Write-InfoMessage -Message "  ID: $($result.id)"
            Write-InfoMessage -Message "  Name: $($result.name)"
            return $result
        }
        finally {
            if (Test-Path -Path $tempFile) {
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Show-WorkflowGuidance {
    <#
    .SYNOPSIS
        Displays guidance for configuring GitHub Actions workflows.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-SectionHeader -Title 'Setup Complete!'
    Write-InfoMessage -Message "`nYour GitHub Actions workflow should now be able to authenticate using OIDC."
    Write-InfoMessage -Message 'Make sure your workflow has the following permissions:'
    Write-Host @'

permissions:
  id-token: write
  contents: read

'@ -ForegroundColor Gray

    Write-InfoMessage -Message 'And uses the azure/login action like this:'
    Write-Host @'

- uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

'@ -ForegroundColor Gray
}
#endregion Helper Functions

#region Main Script
try {
    Write-SectionHeader -Title 'Federated Identity Credential Setup'

    # Verify Azure CLI login
    $null = Test-AzureCliLogin

    # Get the App Registration
    $app = Get-AppRegistration -Name $AppName -ObjectId $AppObjectId
    $resolvedAppObjectId = $app.id

    # Get existing federated credentials
    $existingCredentials = Get-FederatedCredentials -AppObjectId $resolvedAppObjectId

    if ($null -ne $existingCredentials -and $existingCredentials.Count -gt 0) {
        Write-InfoMessage -Message 'Existing federated credentials:' -ForegroundColor Cyan
        foreach ($cred in $existingCredentials) {
            Write-InfoMessage -Message "  - Name: $($cred.name)"
            Write-Host "    Subject: $($cred.subject)" -ForegroundColor Gray
            Write-Host ''
        }
    }

    # Define the subject claim for the GitHub environment
    $subjectClaim = "repo:${GitHubOrg}/${GitHubRepo}:environment:${Environment}"
    $credentialName = "github-actions-${Environment}-environment"

    # Check if credential already exists
    $existingCred = $existingCredentials | Where-Object { $_.subject -eq $subjectClaim }

    if ($null -ne $existingCred) {
        Write-InfoMessage -Message "Federated credential for subject '$subjectClaim' already exists." -ForegroundColor Green
        Write-InfoMessage -Message "Credential Name: $($existingCred.name)"
        exit 0
    }

    # Create the environment federated credential
    $null = New-FederatedCredential `
        -AppObjectId $resolvedAppObjectId `
        -CredentialName $credentialName `
        -Subject $subjectClaim `
        -Description "GitHub Actions OIDC for $GitHubOrg/$GitHubRepo $Environment environment"
    #endregion Main Script

    #region Optional Credentials
    Write-SectionHeader -Title 'Additional Credential Options'

    $createBranch = Read-Host "`nDo you want to create a credential for the 'main' branch? (y/N)"
    if ($createBranch -eq 'y' -or $createBranch -eq 'Y') {
        $branchSubject = "repo:${GitHubOrg}/${GitHubRepo}:ref:refs/heads/main"
        $branchCredName = 'github-actions-main-branch'

        $branchExists = $existingCredentials | Where-Object { $_.subject -eq $branchSubject }
        if ($null -eq $branchExists) {
            $null = New-FederatedCredential `
                -AppObjectId $resolvedAppObjectId `
                -CredentialName $branchCredName `
                -Subject $branchSubject `
                -Description "GitHub Actions OIDC for $GitHubOrg/$GitHubRepo main branch"
            Write-InfoMessage -Message 'Created credential for main branch.' -ForegroundColor Green
        }
        else {
            Write-InfoMessage -Message 'Credential for main branch already exists.' -ForegroundColor Yellow
        }
    }

    $createPR = Read-Host 'Do you want to create a credential for pull requests? (y/N)'
    if ($createPR -eq 'y' -or $createPR -eq 'Y') {
        $prSubject = "repo:${GitHubOrg}/${GitHubRepo}:pull_request"
        $prCredName = 'github-actions-pull-request'

        $prExists = $existingCredentials | Where-Object { $_.subject -eq $prSubject }
        if ($null -eq $prExists) {
            $null = New-FederatedCredential `
                -AppObjectId $resolvedAppObjectId `
                -CredentialName $prCredName `
                -Subject $prSubject `
                -Description "GitHub Actions OIDC for $GitHubOrg/$GitHubRepo pull requests"
            Write-InfoMessage -Message 'Created credential for pull requests.' -ForegroundColor Green
        }
        else {
            Write-InfoMessage -Message 'Credential for pull requests already exists.' -ForegroundColor Yellow
        }
    }
    #endregion Optional Credentials

    # Show workflow guidance
    Show-WorkflowGuidance
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Restore original preferences
    $ErrorActionPreference = $script:OriginalErrorActionPreference
}
