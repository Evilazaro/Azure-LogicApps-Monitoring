# PoProcAPI - Distributed Tracing Implementation

## Overview

This document describes the distributed tracing implementation for PoProcAPI using Application Insights and OpenTelemetry following ASP.NET Core best practices.

## Architecture

The implementation follows industry best practices and patterns from the PoWebApp project, providing comprehensive distributed tracing capabilities:

### Key Components

1. **OpenTelemetry with Azure Monitor**
   - Azure.Monitor.OpenTelemetry.AspNetCore package (v1.4.0)
   - Automatic instrumentation for ASP.NET Core and HttpClient
   - W3C Trace Context propagation

2. **Diagnostics Configuration** (`Diagnostics/DiagnosticsConfig.cs`)
   - Centralized configuration for ActivitySources
   - Semantic conventions for consistent tagging
   - Baggage keys for cross-service correlation

3. **Activity Extensions** (`Diagnostics/ActivityExtensions.cs`)
   - Helper methods for exception recording
   - Order context enrichment
   - HTTP response context
   - W3C Trace Context retrieval

4. **Structured Logging** (`Diagnostics/StructuredLogging.cs`)
   - Trace correlation in logs
   - Consistent logging patterns
   - Contextual logging scopes

5. **Trace Enrichment Middleware** (`Middleware/TraceEnrichmentMiddleware.cs`)
   - Automatic request/response enrichment
   - Client IP tracking
   - Correlation ID management
   - Exception handling

## Features

### Automatic Instrumentation

✅ **ASP.NET Core Requests**
- Automatic span creation for HTTP requests
- Request/response enrichment
- HTTP method, path, status code tracking

✅ **HTTP Client Calls**
- Automatic dependency tracking
- Request/response details
- Exception recording

✅ **Custom Business Operations**
- Order processing activities
- Validation spans
- Processing spans

### Trace Enrichment

✅ **Request Context**
- HTTP method, path, scheme, host
- Content length
- User agent
- Client IP address

✅ **Response Context**
- Status code
- Content length
- Response time

✅ **Business Context**
- Order ID
- Order quantity
- Order total
- Business flow

✅ **Correlation**
- Trace ID and Span ID
- Correlation ID (X-Correlation-Id header)
- Baggage propagation

### Structured Logging

✅ **Correlated Logs**
- Every log includes TraceId and SpanId
- Automatic correlation with traces
- Contextual properties

✅ **Event Tracking**
- Named events (e.g., OrderProcessingStarted)
- Custom properties
- Performance metrics

## Configuration

### Application Insights Connection String

The connection string can be configured in multiple ways:

1. **appsettings.json**
```json
{
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=...;IngestionEndpoint=..."
}
```

2. **Environment Variable**
```powershell
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = "InstrumentationKey=...;IngestionEndpoint=..."
```

3. **Azure App Service**
- Automatically configured when deployed to Azure App Service
- Connection string is set from Application Insights resource

### Logging Configuration

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "System.Net.Http.HttpClient": "Warning"
    }
  }
}
```

## Usage Examples

### Orders Controller

The `ProcessOrder` endpoint demonstrates comprehensive tracing:

```csharp
[HttpPost(Name = "ProcessOrder")]
public IActionResult ProcessOrder(Order order)
{
    // Create parent activity for entire operation
    using var activity = _activitySource.StartActivity("ProcessOrder", ActivityKind.Server);
    
    // Add order context
    activity?.AddOrderContext(order);
    
    // Create child activities for sub-operations
    using var validationActivity = _activitySource.StartActivity("ValidateOrder", ActivityKind.Internal);
    // ... validation logic ...
    
    using var processingActivity = _activitySource.StartActivity("PerformOrderProcessing", ActivityKind.Internal);
    // ... processing logic ...
}
```

### Structured Logging

```csharp
_logger.LogStructuredInformation(
    "Processing order with ID: {OrderId}",
    "OrderProcessingStarted",
    new Dictionary<string, object>
    {
        ["OrderId"] = order.Id,
        ["OrderDate"] = order.Date.ToString("o"),
        ["OrderTotal"] = order.Total
    });
```

### Exception Handling

```csharp
catch (Exception ex)
{
    // Automatically records exception with semantic conventions
    activity?.RecordException(ex);
    
    _logger.LogStructuredError(ex,
        "Error processing order with ID: {OrderId}",
        new Dictionary<string, object>
        {
            ["OrderId"] = order.Id,
            ["ErrorType"] = ex.GetType().Name
        });
}
```

## Trace Hierarchy

```
ProcessOrder (Server)
├── ValidateOrder (Internal)
│   └── Tags: order.id, validation result
└── PerformOrderProcessing (Internal)
    └── Tags: order.id, processing.type
```

## Semantic Conventions

The implementation follows OpenTelemetry semantic conventions:

### Service Attributes
- `service.name`: PoProcAPI
- `service.version`: 1.0.0
- `service.namespace`: eShopOrders
- `deployment.environment`: Development/Production

### HTTP Attributes
- `http.request.method`
- `http.request.path`
- `http.response.status_code`
- `http.response.body.size`

### Business Attributes
- `order.id`
- `order.quantity`
- `order.amount`

### Cloud Attributes
- `cloud.provider`: azure
- `cloud.platform`: azure_app_service

## Sampling Strategy

- **Development**: AlwaysOnSampler (100% sampling)
- **Production**: ParentBasedSampler with TraceIdRatioBasedSampler (100% sampling)

Adjust the sampling rate in production based on traffic volume:

```csharp
.SetSampler(builder.Environment.IsDevelopment()
    ? new AlwaysOnSampler()
    : new ParentBasedSampler(new TraceIdRatioBasedSampler(0.1))) // 10% sampling
```

## Testing

### Local Testing

1. **Run the API**
```powershell
cd src/PoProcAPI
dotnet run
```

2. **Send Test Request**
```powershell
$order = @{
    Id = 1
    Date = (Get-Date).ToString("o")
    Quantity = 5
    Total = 99.99
    Message = "Test order"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://localhost:7001/Orders" `
    -Method Post `
    -Body $order `
    -ContentType "application/json"
```

3. **Check Response**
The response includes TraceId and SpanId for correlation:
```json
{
  "message": "Order processed successfully",
  "orderId": 1,
  "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
  "spanId": "00f067aa0ba902b7"
}
```

### View Traces in Application Insights

1. Navigate to Azure Portal → Application Insights
2. Go to "Transaction search" or "Performance"
3. Search by TraceId or operation name "ProcessOrder"
4. View end-to-end transaction details

## Best Practices Applied

✅ **Automatic Instrumentation**
- Leverages built-in ASP.NET Core and HttpClient instrumentation
- Reduces manual instrumentation overhead

✅ **Semantic Conventions**
- Follows OpenTelemetry semantic conventions
- Ensures consistency across services

✅ **Context Propagation**
- W3C Trace Context standard
- Baggage for business context

✅ **Structured Logging**
- All logs correlated with traces
- Consistent log structure

✅ **Exception Handling**
- Proper exception recording
- Stack traces captured
- Error status codes

✅ **Performance**
- Efficient sampling strategies
- Filtered endpoints (health checks, swagger)
- Minimal overhead

✅ **Observability**
- Request/response details
- Business metrics
- Custom spans for operations

## Troubleshooting

### No Traces in Application Insights

1. Check connection string configuration
2. Verify network connectivity to Azure
3. Check sampling settings
4. Review Application Insights ingestion delay (2-5 minutes)

### Missing Custom Spans

1. Verify ActivitySource registration in Program.cs
2. Check that activities are properly disposed
3. Ensure sampling is not filtering spans

### Logs Not Correlated

1. Verify structured logging extensions are used
2. Check that Activity.Current is available
3. Ensure middleware is registered before controllers

## Performance Considerations

- **Sampling**: Adjust sampling rates based on traffic
- **Filtering**: Health checks and OpenAPI endpoints are filtered
- **Batching**: Azure Monitor automatically batches telemetry
- **Overhead**: < 5% performance impact with full sampling

## Next Steps

1. **Add Custom Metrics**
   - Order processing time
   - Success/failure rates
   - Queue depth

2. **Implement Health Checks**
   - Verify tracing configuration
   - Check Application Insights connectivity

3. **Add Integration Tests**
   - Verify trace propagation
   - Validate span creation

4. **Configure Alerts**
   - High error rates
   - Performance degradation
   - Missing traces

## Resources

- [OpenTelemetry .NET Documentation](https://opentelemetry.io/docs/instrumentation/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable?tabs=aspnetcore)
- [Distributed Tracing Best Practices](https://learn.microsoft.com/azure/azure-monitor/app/distributed-tracing-telemetry-correlation)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
