# Quick Start Guide - Distributed Tracing

## 🚀 Getting Started in 5 Minutes

### Prerequisites
- .NET 9.0 SDK
- Azure Application Insights resource (or use emulator for local testing)
- Visual Studio Code or Visual Studio 2022

---

## Step 1: Verify Configuration

Run the validation script:
```powershell
cd src/PoWebApp
.\validate-tracing.ps1
```

Expected output: ✓ All checks passed or minimal warnings

---

## Step 2: Configure Application Insights

### Option A: Local Development
Edit `appsettings.Development.json`:
```json
{
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=your-key;IngestionEndpoint=..."
}
```

### Option B: Environment Variable
```powershell
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=your-key;..."
```

### Option C: Azure App Service
Connection string is automatically injected by Azure

---

## Step 3: Run the Application

```powershell
dotnet run
```

The application will start on `https://localhost:5001`

---

## Step 4: Verify Distributed Tracing

### Check Health Endpoint
```powershell
# View tracing health status
curl https://localhost:5001/health -k | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

Expected response:
```json
{
  "status": "Healthy",
  "checks": [{
    "name": "distributed-tracing",
    "status": "Healthy",
    "data": {
      "ApplicationInsightsConfigured": true,
      "OrderActivitySourceAvailable": true,
      "MessagingActivitySourceAvailable": true
    }
  }]
}
```

### Test Order Processing
1. Navigate to the Orders page in the application
2. Click "Process Orders" or trigger the order processing functionality
3. Wait 2-3 minutes for telemetry to appear in Application Insights

---

## Step 5: View Traces in Application Insights

### Azure Portal
1. Open Azure Portal → Application Insights
2. Go to "Transaction Search" or "Logs"
3. Query recent traces:

```kusto
traces
| where timestamp > ago(30m)
| where cloud_RoleName == "PoWebApp"
| order by timestamp desc
| take 50
```

### View Distributed Trace
```kusto
requests
| where name contains "AddOrderMessageToQueue"
| project operation_Id, timestamp, name, duration
| take 1
| join kind=inner (
    dependencies
    | where type == "Azure Queue"
) on operation_Id
| project timestamp, RequestName = name, DependencyName = name1, duration
```

---

## What You Should See

### ✅ Traces
- HTTP requests to your application
- Order processing operations
- Queue message sends
- All correlated with TraceId and SpanId

### ✅ Dependencies
- Azure Queue operations
- HTTP client calls to external services
- Automatic parent-child relationships

### ✅ Custom Dimensions
- `order.id` - Order identifier
- `order.quantity` - Order quantity
- `order.amount` - Order total
- `batch.size` - Batch size for bulk operations
- `batch.success_count` - Successfully processed items

---

## Common Scenarios

### Scenario 1: Process 10,000 Orders
```csharp
// Already implemented in Orders.cs
var successCount = await orders.AddOrderMessageToQueueAsync();
```

**Traces Generated:**
- 1 parent span: `AddOrderMessageToQueue`
- 10,000 child spans: `SendQueueMessage` (one per order)
- All correlated with trace context

### Scenario 2: Track Custom Business Operation
```csharp
using var activity = DiagnosticsConfig.ActivitySources.Orders.StartActivity(
    "MyCustomOperation",
    ActivityKind.Internal);

activity?.AddOrderContext(orderId, quantity, total);

try {
    // Your business logic
    await DoWork();
    activity?.SetStatus(ActivityStatusCode.Ok);
} catch (Exception ex) {
    activity?.RecordException(ex);
    throw;
}
```

### Scenario 3: Correlated Logging
```csharp
using var scope = _logger.BeginCorrelatedScope(orderId);
_logger.LogInformation("Processing order {OrderId}", orderId);
// Logs automatically include TraceId and SpanId
```

---

## Troubleshooting

### No traces appearing?

1. **Check connection string**:
   ```powershell
   $env:APPLICATIONINSIGHTS_CONNECTION_STRING
   ```

2. **Verify Application Insights is enabled**:
   ```powershell
   curl https://localhost:5001/health -k
   ```

3. **Check logs for errors**:
   ```powershell
   dotnet run --verbosity detailed
   ```

4. **Wait longer**: Initial ingestion can take 2-5 minutes

### Traces not correlated?

- Verify `Activity.Current` is not null
- Check that HttpClient is created via `IHttpClientFactory`
- Ensure activity sources are registered in Program.cs

### Performance issues?

- Review sampling configuration in Program.cs
- Check Application Insights throttling limits
- Use Live Metrics for real-time diagnostics

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   PoWebApp (Blazor)                 │
│  ┌───────────────────────────────────────────────┐  │
│  │     OpenTelemetry + Azure Monitor             │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │   Activity Sources                      │  │  │
│  │  │   - Orders   - UI   - Messaging        │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────┐  │  │
│  │  │   Instrumentation                       │  │  │
│  │  │   - ASP.NET Core  - HTTP Client        │  │  │
│  │  └─────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                         │
                         │ W3C Trace Context
                         ▼
┌─────────────────────────────────────────────────────┐
│           Azure Application Insights                │
│  - Distributed Tracing   - Live Metrics            │
│  - Application Map       - Transaction Search       │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│              Azure Queue Storage                    │
│  (Orders processed with trace propagation)          │
└─────────────────────────────────────────────────────┘
```

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `Program.cs` | OpenTelemetry & Application Insights configuration |
| `Diagnostics/DiagnosticsConfig.cs` | Centralized configuration & semantic conventions |
| `Diagnostics/ActivityExtensions.cs` | Helper methods for adding context to traces |
| `Diagnostics/StructuredLogging.cs` | Correlated logging utilities |
| `Middleware/TraceEnrichmentMiddleware.cs` | Automatic trace enrichment |
| `HealthChecks/DistributedTracingHealthCheck.cs` | Health check for tracing |
| `Components/Orders.cs` | Example: Batch processing with tracing |
| `Examples/DistributedTracingExample.cs` | Comprehensive usage examples |

---

## Next Steps

1. ✅ **Read**: `DISTRIBUTED_TRACING.md` for detailed documentation
2. ✅ **Review**: `Examples/DistributedTracingExample.cs` for usage patterns
3. ✅ **Explore**: Application Insights Application Map
4. ✅ **Monitor**: Set up alerts for exceptions and performance issues
5. ✅ **Optimize**: Review traces and identify bottlenecks

---

## Support Resources

- [Full Documentation](./DISTRIBUTED_TRACING.md)
- [Fixes & Improvements](./FIXES_AND_IMPROVEMENTS.md)
- [OpenTelemetry .NET Docs](https://opentelemetry.io/docs/languages/net/)
- [Azure Monitor Docs](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)

---

**Status**: ✅ Production Ready | ✅ All Tests Passing | ✅ Full Trace Coverage

**Last Updated**: December 9, 2025
