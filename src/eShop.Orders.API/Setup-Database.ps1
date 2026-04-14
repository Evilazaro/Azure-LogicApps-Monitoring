# Entity Framework Core Database Migration Script
# This script automates the EF Core migration process for eShop.Orders.API

param(
    [Parameter(Mandatory=$true, HelpMessage="SQL Server FQDN from Azure (e.g., ordersserver123abc.database.windows.net)")]
    [string]$SqlServerFqdn,
    
    [Parameter(Mandatory=$true, HelpMessage="Database name (e.g., ordersdb123abc)")]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateMigration,
    
    [Parameter(Mandatory=$false)]
    [switch]$UpdateDatabase,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateScript
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "EF Core Migration Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Project path
$projectPath = "$PSScriptRoot"
Write-Host "Project Path: $projectPath" -ForegroundColor Green

# Connection string configuration
$connectionString = "Server=tcp:$SqlServerFqdn,1433;Initial Catalog=$DatabaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;"

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  SQL Server: $SqlServerFqdn" -ForegroundColor White
Write-Host "  Database: $DatabaseName" -ForegroundColor White
Write-Host ""

# Update appsettings.json files
Write-Host "Updating appsettings.json files..." -ForegroundColor Yellow

$appsettingsPath = Join-Path $projectPath "appsettings.json"
$appsettingsDevelopmentPath = Join-Path $projectPath "appsettings.Development.json"

if (Test-Path $appsettingsPath) {
    $appsettings = Get-Content $appsettingsPath -Raw | ConvertFrom-Json
    $appsettings.ConnectionStrings.OrdersDatabase = $connectionString
    $appsettings | ConvertTo-Json -Depth 10 | Set-Content $appsettingsPath
    Write-Host "  ✓ Updated appsettings.json" -ForegroundColor Green
}

if (Test-Path $appsettingsDevelopmentPath) {
    $appsettingsDevelopment = Get-Content $appsettingsDevelopmentPath -Raw | ConvertFrom-Json
    $appsettingsDevelopment.ConnectionStrings.OrdersDatabase = $connectionString
    $appsettingsDevelopment | ConvertTo-Json -Depth 10 | Set-Content $appsettingsDevelopmentPath
    Write-Host "  ✓ Updated appsettings.Development.json" -ForegroundColor Green
}

Write-Host ""

# Check if dotnet ef is installed
Write-Host "Checking for dotnet-ef tool..." -ForegroundColor Yellow
$efTool = dotnet tool list --global | Select-String "dotnet-ef"

if (-not $efTool) {
    Write-Host "  dotnet-ef tool not found. Installing..." -ForegroundColor Yellow
    dotnet tool install --global dotnet-ef
    Write-Host "  ✓ Installed dotnet-ef tool" -ForegroundColor Green
} else {
    Write-Host "  ✓ dotnet-ef tool is installed" -ForegroundColor Green
}

Write-Host ""

# Change to project directory
Push-Location $projectPath

try {
    # Create migration
    if ($CreateMigration) {
        Write-Host "Creating EF Core migration..." -ForegroundColor Yellow
        dotnet ef migrations add InitialCreate --context OrderDbContext
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Migration created successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to create migration" -ForegroundColor Red
            exit 1
        }
        Write-Host ""
    }

    # Update database
    if ($UpdateDatabase) {
        Write-Host "Applying migration to database..." -ForegroundColor Yellow
        Write-Host "  Connecting to: $SqlServerFqdn" -ForegroundColor White
        
        # Ensure Azure login
        Write-Host "  Checking Azure authentication..." -ForegroundColor White
        az account show | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Not logged in to Azure. Please login..." -ForegroundColor Yellow
            az login
        }
        
        dotnet ef database update --context OrderDbContext
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Database updated successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to update database" -ForegroundColor Red
            exit 1
        }
        Write-Host ""
    }

    # Generate SQL script
    if ($GenerateScript) {
        $scriptPath = Join-Path $projectPath "migration.sql"
        Write-Host "Generating SQL migration script..." -ForegroundColor Yellow
        
        dotnet ef migrations script -o $scriptPath --context OrderDbContext
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ SQL script generated: $scriptPath" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to generate SQL script" -ForegroundColor Red
            exit 1
        }
        Write-Host ""
    }

    # If no action specified, show help
    if (-not $CreateMigration -and -not $UpdateDatabase -and -not $GenerateScript) {
        Write-Host "No action specified. Please use one or more of the following switches:" -ForegroundColor Yellow
        Write-Host "  -CreateMigration   : Create EF Core migration files" -ForegroundColor White
        Write-Host "  -UpdateDatabase    : Apply migration to database" -ForegroundColor White
        Write-Host "  -GenerateScript    : Generate SQL migration script" -ForegroundColor White
        Write-Host ""
        Write-Host "Example:" -ForegroundColor Cyan
        Write-Host "  .\Setup-Database.ps1 -SqlServerFqdn 'server.database.windows.net' -DatabaseName 'ordersdb' -CreateMigration -UpdateDatabase" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "Migration process completed!" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Cyan
}
finally {
    Pop-Location
}
