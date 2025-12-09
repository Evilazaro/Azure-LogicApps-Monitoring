# Distributed Tracing Validation Script
# This script validates that distributed tracing is properly configured

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Distributed Tracing Validation" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# 1. Check if orders.json exists and is valid
Write-Host "1. Checking orders.json..." -ForegroundColor Yellow
if (Test-Path "orders.json") {
    try {
        $ordersContent = Get-Content "orders.json" -Raw | ConvertFrom-Json
        if ($ordersContent -is [Array]) {
            Write-Host "   ✓ orders.json is valid JSON array with $($ordersContent.Count) orders" -ForegroundColor Green
        } else {
            Write-Host "   ✗ orders.json is not an array" -ForegroundColor Red
            $errors++
        }
    } catch {
        Write-Host "   ✗ orders.json is not valid JSON: $($_.Exception.Message)" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "   ✗ orders.json not found" -ForegroundColor Red
    $errors++
}

# 2. Check Application Insights connection string
Write-Host "`n2. Checking Application Insights configuration..." -ForegroundColor Yellow
$aiConnectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING
if (-not [string]::IsNullOrEmpty($aiConnectionString)) {
    Write-Host "   ✓ APPLICATIONINSIGHTS_CONNECTION_STRING is set" -ForegroundColor Green
    if ($aiConnectionString -match "InstrumentationKey=") {
        Write-Host "   ✓ Connection string format is valid" -ForegroundColor Green
    } else {
        Write-Host "   ⚠ Connection string may be invalid" -ForegroundColor Yellow
        $warnings++
    }
} else {
    Write-Host "   ⚠ APPLICATIONINSIGHTS_CONNECTION_STRING not set (check appsettings.Development.json)" -ForegroundColor Yellow
    $warnings++
}

# 3. Check required NuGet packages
Write-Host "`n3. Checking required NuGet packages..." -ForegroundColor Yellow
$csprojPath = "PoWebApp.csproj"
if (Test-Path $csprojPath) {
    $csprojContent = Get-Content $csprojPath -Raw
    
    $requiredPackages = @(
        "Azure.Monitor.OpenTelemetry.AspNetCore",
        "Azure.Storage.Queues",
        "Microsoft.ApplicationInsights.AspNetCore"
    )
    
    foreach ($package in $requiredPackages) {
        if ($csprojContent -match $package) {
            Write-Host "   ✓ $package is referenced" -ForegroundColor Green
        } else {
            Write-Host "   ✗ $package is missing" -ForegroundColor Red
            $errors++
        }
    }
} else {
    Write-Host "   ✗ PoWebApp.csproj not found" -ForegroundColor Red
    $errors++
}

# 4. Check critical files exist
Write-Host "`n4. Checking critical files..." -ForegroundColor Yellow
$requiredFiles = @(
    "Program.cs",
    "Diagnostics/DiagnosticsConfig.cs",
    "Diagnostics/ActivityExtensions.cs",
    "Diagnostics/StructuredLogging.cs",
    "Components/Orders.cs",
    "Components/Order.cs",
    "Middleware/TraceEnrichmentMiddleware.cs",
    "HealthChecks/DistributedTracingHealthCheck.cs"
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   ✓ $file exists" -ForegroundColor Green
    } else {
        Write-Host "   ✗ $file is missing" -ForegroundColor Red
        $errors++
    }
}

# 5. Build the project
Write-Host "`n5. Building the project..." -ForegroundColor Yellow
try {
    $buildOutput = dotnet build --no-incremental 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Build succeeded" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Build failed" -ForegroundColor Red
        Write-Host "   Build output: $buildOutput" -ForegroundColor Red
        $errors++
    }
} catch {
    Write-Host "   ✗ Build error: $($_.Exception.Message)" -ForegroundColor Red
    $errors++
}

# 6. Check for common issues in code
Write-Host "`n6. Checking for common issues..." -ForegroundColor Yellow

# Check Orders.cs for the fixed JSON parsing
if (Test-Path "Components/Orders.cs") {
    $ordersContent = Get-Content "Components/Orders.cs" -Raw
    if ($ordersContent -match 'GetProperty\("orders"\)') {
        Write-Host "   ✗ Orders.cs still contains old JSON parsing bug" -ForegroundColor Red
        $errors++
    } else {
        Write-Host "   ✓ Orders.cs JSON parsing is fixed" -ForegroundColor Green
    }
    
    if ($ordersContent -match 'AddApplicationInsightsTelemetry') {
        Write-Host "   ⚠ Duplicate Application Insights registration found" -ForegroundColor Yellow
        $warnings++
    }
}

# Check Order.cs for JsonPropertyName attributes
if (Test-Path "Components/Order.cs") {
    $orderContent = Get-Content "Components/Order.cs" -Raw
    if ($orderContent -match '\[JsonPropertyName') {
        Write-Host "   ✓ Order.cs has proper JSON property mappings" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Order.cs missing JSON property mappings" -ForegroundColor Red
        $errors++
    }
}

# 7. Summary
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "✓ All checks passed!" -ForegroundColor Green
    Write-Host "`nYour application is ready for distributed tracing." -ForegroundColor Green
    exit 0
} elseif ($errors -eq 0) {
    Write-Host "⚠ Validation completed with $warnings warning(s)" -ForegroundColor Yellow
    Write-Host "`nYour application should work, but review the warnings above." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "✗ Validation failed with $errors error(s) and $warnings warning(s)" -ForegroundColor Red
    Write-Host "`nPlease fix the errors above before running the application." -ForegroundColor Red
    exit 1
}
