using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using PoProcAPI.Diagnostics;
using PoProcAPI.Middleware;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure OpenTelemetry with Azure Monitor for Distributed Tracing
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: DiagnosticsConfig.ServiceName,
            serviceVersion: DiagnosticsConfig.ServiceVersion,
            serviceInstanceId: Environment.MachineName)
        .AddAttributes(new Dictionary<string, object>
        {
            [DiagnosticsConfig.SemanticConventions.ServiceNamespace] = DiagnosticsConfig.ServiceNamespace,
            [DiagnosticsConfig.SemanticConventions.DeploymentEnvironment] = builder.Environment.EnvironmentName,
            [DiagnosticsConfig.SemanticConventions.CloudProvider] = "azure",
            [DiagnosticsConfig.SemanticConventions.CloudPlatform] = "azure_app_service",
            ["host.name"] = Environment.MachineName,
            ["host.type"] = Environment.OSVersion.Platform.ToString()
        }))
    .WithTracing(tracing => tracing
        // Add ASP.NET Core instrumentation for automatic request tracking
        .AddAspNetCoreInstrumentation(options =>
        {
            options.RecordException = true;

            // Filter out health check and OpenAPI endpoints
            options.Filter = (httpContext) =>
            {
                var path = httpContext.Request.Path.Value;
                if (path == null) return true;

                return !path.Contains("/health", StringComparison.OrdinalIgnoreCase)
                    && !path.Contains("/swagger", StringComparison.OrdinalIgnoreCase)
                    && !path.Contains("/openapi", StringComparison.OrdinalIgnoreCase);
            };

            options.EnrichWithHttpRequest = (activity, httpRequest) =>
            {
                activity.SetTag("http.request.method", httpRequest.Method);
                activity.SetTag("http.request.path", httpRequest.Path);
                activity.SetTag("http.scheme", httpRequest.Scheme);
                activity.SetTag("http.host", httpRequest.Host.ToString());
            };

            options.EnrichWithHttpResponse = (activity, httpResponse) =>
            {
                activity.SetTag("http.response.status_code", httpResponse.StatusCode);

                if (httpResponse.ContentLength.HasValue)
                {
                    activity.SetTag("http.response.body.size", httpResponse.ContentLength.Value);
                }
            };
        })
        // Add HTTP client instrumentation for automatic dependency tracking
        .AddHttpClientInstrumentation(options =>
        {
            options.RecordException = true;

            options.EnrichWithHttpRequestMessage = (activity, httpRequestMessage) =>
            {
                activity.SetTag("http.request.method", httpRequestMessage.Method.ToString());
                activity.SetTag("http.url", httpRequestMessage.RequestUri?.ToString());
            };

            options.EnrichWithHttpResponseMessage = (activity, httpResponseMessage) =>
            {
                activity.SetTag("http.response.status_code", (int)httpResponseMessage.StatusCode);
            };
        })
        // Add custom activity sources for business operations
        .AddSource(DiagnosticsConfig.ActivitySources.Orders.Name)
        .AddSource(DiagnosticsConfig.ActivitySources.API.Name)

        // Configure sampling - sample all traces in development, adaptive in production
        .SetSampler(builder.Environment.IsDevelopment()
            ? new AlwaysOnSampler()
            : new ParentBasedSampler(new TraceIdRatioBasedSampler(1.0))))
    // Enable Azure Monitor with Application Insights
    .UseAzureMonitor(options =>
    {
        // Connection string from configuration or environment variable
        var connectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]
            ?? Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");

        if (!string.IsNullOrEmpty(connectionString))
        {
            options.ConnectionString = connectionString;
        }

        // Enable Live Metrics for real-time monitoring
        options.EnableLiveMetrics = true;
    });

// Add HttpClient for making HTTP requests with automatic tracing
builder.Services.AddHttpClient();

var app = builder.Build();

app.MapOpenApi();
app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();

// Add trace enrichment middleware before authorization
app.UseTraceEnrichment();

app.UseAuthorization();

app.MapControllers();

app.Run();
