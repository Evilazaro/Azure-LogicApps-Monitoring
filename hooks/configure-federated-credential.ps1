#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures federated identity credentials for GitHub Actions OIDC authentication.

.DESCRIPTION
    This script adds or updates federated identity credentials in an Azure AD App Registration
    to enable GitHub Actions workflows to authenticate using OIDC (OpenID Connect).

.PARAMETER AppName
    The display name of the Azure AD App Registration.

.PARAMETER AppObjectId
    The Object ID of the Azure AD App Registration. If not provided, the script will look it up by AppName.

.PARAMETER GitHubOrg
    The GitHub organization or username. Default: Evilazaro

.PARAMETER GitHubRepo
    The GitHub repository name. Default: Azure-LogicApps-Monitoring

.PARAMETER Environment
    The GitHub Environment name to configure. Default: dev

.EXAMPLE
    ./configure-federated-credential.ps1 -AppName "my-app-registration"

.EXAMPLE
    ./configure-federated-credential.ps1 -AppObjectId "00000000-0000-0000-0000-000000000000" -Environment "prod"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AppName,

    [Parameter(Mandatory = $false)]
    [string]$AppObjectId,

    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg = "Evilazaro",

    [Parameter(Mandatory = $false)]
    [string]$GitHubRepo = "Azure-LogicApps-Monitoring",

    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Federated Identity Credential Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if user is logged in to Azure CLI
Write-Host "`nChecking Azure CLI login status..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in to Azure CLI. Please run 'az login' first." -ForegroundColor Red
    exit 1
}
Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "Subscription: $($account.name) ($($account.id))" -ForegroundColor Green

# Get the App Registration Object ID
if (-not $AppObjectId) {
    if (-not $AppName) {
        Write-Host "`nNo AppName or AppObjectId provided. Listing available App Registrations..." -ForegroundColor Yellow
        $apps = az ad app list --all --query "[].{DisplayName:displayName, AppId:appId, ObjectId:id}" -o json | ConvertFrom-Json
        
        if ($apps.Count -eq 0) {
            Write-Host "No App Registrations found in this tenant." -ForegroundColor Red
            exit 1
        }

        Write-Host "`nAvailable App Registrations:" -ForegroundColor Cyan
        $apps | Format-Table -AutoSize
        
        $AppName = Read-Host "Enter the App Registration display name"
    }

    Write-Host "`nLooking up App Registration: $AppName" -ForegroundColor Yellow
    $app = az ad app list --display-name $AppName --query "[0]" -o json | ConvertFrom-Json
    
    if (-not $app) {
        Write-Host "App Registration '$AppName' not found." -ForegroundColor Red
        exit 1
    }
    
    $AppObjectId = $app.id
    Write-Host "Found App Registration:" -ForegroundColor Green
    Write-Host "  Display Name: $($app.displayName)" -ForegroundColor White
    Write-Host "  App ID (Client ID): $($app.appId)" -ForegroundColor White
    Write-Host "  Object ID: $AppObjectId" -ForegroundColor White
}

# List existing federated credentials
Write-Host "`nChecking existing federated credentials..." -ForegroundColor Yellow
$existingCredentials = az ad app federated-credential list --id $AppObjectId -o json 2>$null | ConvertFrom-Json

if ($existingCredentials -and $existingCredentials.Count -gt 0) {
    Write-Host "Existing federated credentials:" -ForegroundColor Cyan
    foreach ($cred in $existingCredentials) {
        Write-Host "  - Name: $($cred.name)" -ForegroundColor White
        Write-Host "    Subject: $($cred.subject)" -ForegroundColor Gray
        Write-Host ""
    }
}

# Define the subject claim for the GitHub environment
$subjectClaim = "repo:${GitHubOrg}/${GitHubRepo}:environment:${Environment}"
$credentialName = "github-actions-${Environment}-environment"

# Check if credential already exists
$existingCred = $existingCredentials | Where-Object { $_.subject -eq $subjectClaim }

if ($existingCred) {
    Write-Host "Federated credential for subject '$subjectClaim' already exists." -ForegroundColor Green
    Write-Host "Credential Name: $($existingCred.name)" -ForegroundColor White
    exit 0
}

# Create the federated credential
Write-Host "`nCreating federated credential..." -ForegroundColor Yellow
Write-Host "  Name: $credentialName" -ForegroundColor White
Write-Host "  Issuer: https://token.actions.githubusercontent.com" -ForegroundColor White
Write-Host "  Subject: $subjectClaim" -ForegroundColor White
Write-Host "  Audience: api://AzureADTokenExchange" -ForegroundColor White

$credentialParams = @{
    name        = $credentialName
    issuer      = "https://token.actions.githubusercontent.com"
    subject     = $subjectClaim
    audiences   = @("api://AzureADTokenExchange")
    description = "GitHub Actions OIDC for $GitHubOrg/$GitHubRepo $Environment environment"
} | ConvertTo-Json -Compress

try {
    $result = az ad app federated-credential create --id $AppObjectId --parameters $credentialParams -o json | ConvertFrom-Json
    Write-Host "`nFederated credential created successfully!" -ForegroundColor Green
    Write-Host "  ID: $($result.id)" -ForegroundColor White
    Write-Host "  Name: $($result.name)" -ForegroundColor White
}
catch {
    Write-Host "Failed to create federated credential: $_" -ForegroundColor Red
    exit 1
}

# Optionally create credentials for branch and pull request
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Additional Credential Options" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$createBranch = Read-Host "`nDo you want to create a credential for the 'main' branch? (y/N)"
if ($createBranch -eq 'y' -or $createBranch -eq 'Y') {
    $branchSubject = "repo:${GitHubOrg}/${GitHubRepo}:ref:refs/heads/main"
    $branchCredName = "github-actions-main-branch"
    
    $branchExists = $existingCredentials | Where-Object { $_.subject -eq $branchSubject }
    if (-not $branchExists) {
        $branchParams = @{
            name        = $branchCredName
            issuer      = "https://token.actions.githubusercontent.com"
            subject     = $branchSubject
            audiences   = @("api://AzureADTokenExchange")
            description = "GitHub Actions OIDC for $GitHubOrg/$GitHubRepo main branch"
        } | ConvertTo-Json -Compress
        
        az ad app federated-credential create --id $AppObjectId --parameters $branchParams -o json | Out-Null
        Write-Host "Created credential for main branch." -ForegroundColor Green
    }
    else {
        Write-Host "Credential for main branch already exists." -ForegroundColor Yellow
    }
}

$createPR = Read-Host "Do you want to create a credential for pull requests? (y/N)"
if ($createPR -eq 'y' -or $createPR -eq 'Y') {
    $prSubject = "repo:${GitHubOrg}/${GitHubRepo}:pull_request"
    $prCredName = "github-actions-pull-request"
    
    $prExists = $existingCredentials | Where-Object { $_.subject -eq $prSubject }
    if (-not $prExists) {
        $prParams = @{
            name        = $prCredName
            issuer      = "https://token.actions.githubusercontent.com"
            subject     = $prSubject
            audiences   = @("api://AzureADTokenExchange")
            description = "GitHub Actions OIDC for $GitHubOrg/$GitHubRepo pull requests"
        } | ConvertTo-Json -Compress
        
        az ad app federated-credential create --id $AppObjectId --parameters $prParams -o json | Out-Null
        Write-Host "Created credential for pull requests." -ForegroundColor Green
    }
    else {
        Write-Host "Credential for pull requests already exists." -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nYour GitHub Actions workflow should now be able to authenticate using OIDC." -ForegroundColor White
Write-Host "Make sure your workflow has the following permissions:" -ForegroundColor White
Write-Host @"

permissions:
  id-token: write
  contents: read

"@ -ForegroundColor Gray

Write-Host "And uses the azure/login action like this:" -ForegroundColor White
Write-Host @"

- uses: azure/login@v2
  with:
    client-id: `${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: `${{ secrets.AZURE_TENANT_ID }}
    subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}

"@ -ForegroundColor Gray
