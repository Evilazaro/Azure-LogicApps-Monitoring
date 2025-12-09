# Distributed Tracing Validation Script for PoProcAPI
# This script validates that distributed tracing is properly configured

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PoProcAPI Distributed Tracing Validator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0
$warnings = 0

function Test-Check {
    param(
        [string]$Description,
        [scriptblock]$Test,
        [string]$SuccessMessage,
        [string]$FailureMessage,
        [bool]$IsWarning = $false
    )
    
    Write-Host "Checking: $Description..." -NoNewline
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host " ✓ PASS" -ForegroundColor Green
            Write-Host "  → $SuccessMessage" -ForegroundColor Gray
            $script:passed++
            return $true
        } else {
            if ($IsWarning) {
                Write-Host " ⚠ WARNING" -ForegroundColor Yellow
                Write-Host "  → $FailureMessage" -ForegroundColor Gray
                $script:warnings++
            } else {
                Write-Host " ✗ FAIL" -ForegroundColor Red
                Write-Host "  → $FailureMessage" -ForegroundColor Gray
                $script:failed++
            }
            return $false
        }
    } catch {
        Write-Host " ✗ ERROR" -ForegroundColor Red
        Write-Host "  → $_" -ForegroundColor Gray
        $script:failed++
        return $false
    }
}

# Change to the PoProcAPI directory
$projectPath = $PSScriptRoot
if (-not $projectPath) {
    $projectPath = "."
}

Write-Host "Project Path: $projectPath" -ForegroundColor Gray
Write-Host ""

# Check 1: Verify Azure.Monitor.OpenTelemetry.AspNetCore package
Test-Check -Description "Azure.Monitor.OpenTelemetry.AspNetCore package installed" `
    -Test {
        $csproj = Get-Content "$projectPath\PoProcAPI.csproj" -Raw
        $csproj -match 'Azure\.Monitor\.OpenTelemetry\.AspNetCore'
    } `
    -SuccessMessage "Package reference found in PoProcAPI.csproj" `
    -FailureMessage "Package not found. Run: dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore"

# Check 2: Verify DiagnosticsConfig exists
Test-Check -Description "DiagnosticsConfig.cs exists" `
    -Test {
        Test-Path "$projectPath\Diagnostics\DiagnosticsConfig.cs"
    } `
    -SuccessMessage "DiagnosticsConfig.cs found in Diagnostics folder" `
    -FailureMessage "DiagnosticsConfig.cs is missing"

# Check 3: Verify ActivityExtensions exists
Test-Check -Description "ActivityExtensions.cs exists" `
    -Test {
        Test-Path "$projectPath\Diagnostics\ActivityExtensions.cs"
    } `
    -SuccessMessage "ActivityExtensions.cs found in Diagnostics folder" `
    -FailureMessage "ActivityExtensions.cs is missing"

# Check 4: Verify StructuredLogging exists
Test-Check -Description "StructuredLogging.cs exists" `
    -Test {
        Test-Path "$projectPath\Diagnostics\StructuredLogging.cs"
    } `
    -SuccessMessage "StructuredLogging.cs found in Diagnostics folder" `
    -FailureMessage "StructuredLogging.cs is missing"

# Check 5: Verify TraceEnrichmentMiddleware exists
Test-Check -Description "TraceEnrichmentMiddleware.cs exists" `
    -Test {
        Test-Path "$projectPath\Middleware\TraceEnrichmentMiddleware.cs"
    } `
    -SuccessMessage "TraceEnrichmentMiddleware.cs found in Middleware folder" `
    -FailureMessage "TraceEnrichmentMiddleware.cs is missing"

# Check 6: Verify Program.cs has OpenTelemetry configuration
Test-Check -Description "OpenTelemetry configured in Program.cs" `
    -Test {
        $program = Get-Content "$projectPath\Program.cs" -Raw
        ($program -match 'AddOpenTelemetry\(\)') -and ($program -match 'UseAzureMonitor')
    } `
    -SuccessMessage "OpenTelemetry and Azure Monitor configuration found" `
    -FailureMessage "OpenTelemetry configuration missing in Program.cs"

# Check 7: Verify Program.cs has middleware registration
Test-Check -Description "TraceEnrichment middleware registered" `
    -Test {
        $program = Get-Content "$projectPath\Program.cs" -Raw
        $program -match 'UseTraceEnrichment\(\)'
    } `
    -SuccessMessage "Middleware registered in pipeline" `
    -FailureMessage "UseTraceEnrichment() not found in Program.cs"

# Check 8: Verify Orders controller uses ActivitySource
Test-Check -Description "Orders controller uses ActivitySource" `
    -Test {
        $controller = Get-Content "$projectPath\Controllers\Orders.cs" -Raw
        ($controller -match 'ActivitySource') -and ($controller -match 'StartActivity')
    } `
    -SuccessMessage "ActivitySource usage found in Orders controller" `
    -FailureMessage "ActivitySource not properly used in Orders controller"

# Check 9: Verify Orders controller uses structured logging
Test-Check -Description "Orders controller uses structured logging" `
    -Test {
        $controller = Get-Content "$projectPath\Controllers\Orders.cs" -Raw
        $controller -match 'LogStructuredInformation|LogStructuredError'
    } `
    -SuccessMessage "Structured logging found in Orders controller" `
    -FailureMessage "Structured logging not used in Orders controller"

# Check 10: Verify appsettings.json has Application Insights placeholder
Test-Check -Description "Application Insights configuration in appsettings.json" `
    -Test {
        $settings = Get-Content "$projectPath\appsettings.json" -Raw
        $settings -match 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    } `
    -SuccessMessage "Configuration placeholder found" `
    -FailureMessage "APPLICATIONINSIGHTS_CONNECTION_STRING not in appsettings.json"

# Check 11: Verify connection string is set (warning only)
Test-Check -Description "Application Insights connection string configured" `
    -Test {
        $connString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING
        if ([string]::IsNullOrEmpty($connString)) {
            $settings = Get-Content "$projectPath\appsettings.json" | ConvertFrom-Json
            $connString = $settings.APPLICATIONINSIGHTS_CONNECTION_STRING
        }
        -not [string]::IsNullOrEmpty($connString)
    } `
    -SuccessMessage "Connection string is configured" `
    -FailureMessage "Connection string not set. Set APPLICATIONINSIGHTS_CONNECTION_STRING environment variable or in appsettings.json" `
    -IsWarning $true

# Check 12: Verify project builds
Test-Check -Description "Project builds successfully" `
    -Test {
        Push-Location $projectPath
        try {
            $buildOutput = dotnet build --no-restore 2>&1
            $buildSuccess = $LASTEXITCODE -eq 0
            if (-not $buildSuccess) {
                Write-Host ""
                Write-Host "Build output:" -ForegroundColor Yellow
                Write-Host $buildOutput -ForegroundColor Gray
            }
            return $buildSuccess
        } finally {
            Pop-Location
        }
    } `
    -SuccessMessage "Project compiles without errors" `
    -FailureMessage "Project has compilation errors. Run 'dotnet build' to see details"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed:   $passed" -ForegroundColor Green
Write-Host "Failed:   $failed" -ForegroundColor Red
Write-Host "Warnings: $warnings" -ForegroundColor Yellow
Write-Host ""

if ($failed -eq 0) {
    Write-Host "✓ All critical checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Set Application Insights connection string (if not already set)" -ForegroundColor Gray
    Write-Host "2. Run the API: dotnet run" -ForegroundColor Gray
    Write-Host "3. Send a test request to /Orders endpoint" -ForegroundColor Gray
    Write-Host "4. View traces in Application Insights (Azure Portal)" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host "✗ Some checks failed. Please fix the issues above." -ForegroundColor Red
    Write-Host ""
    exit 1
}
