using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using PoWebApp.Components;
using PoWebApp.Diagnostics;
using PoWebApp.HealthChecks;
using PoWebApp.Middleware;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

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

            // Filter out health check endpoints
            options.Filter = (httpContext) =>
            {
                var path = httpContext.Request.Path.Value;
                return !path?.Contains("/health", StringComparison.OrdinalIgnoreCase) ?? true;
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

                // Add response size if available
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

                // Track response time
                if (httpResponseMessage.Headers.TryGetValues("X-Response-Time", out var responseTime))
                {
                    activity.SetTag("http.response.time", responseTime.FirstOrDefault());
                }
            };
        })
        // Add custom activity sources for business operations
        .AddSource(DiagnosticsConfig.ActivitySources.Orders.Name)
        .AddSource(DiagnosticsConfig.ActivitySources.UI.Name)
        .AddSource(DiagnosticsConfig.ActivitySources.Messaging.Name)

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

        // Disable adaptive sampling in development for complete traces
        if (builder.Environment.IsDevelopment())
        {
            // In development, we want all traces
            // Note: Azure Monitor exporter handles its own sampling
        }
    });

// Add HttpClient for making HTTP requests with automatic tracing
builder.Services.AddHttpClient();
builder.Services.AddScoped<Orders>();

// Add health checks for monitoring
builder.Services.AddHealthChecks()
    .AddDistributedTracingHealthCheck();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}
else
{
    var configs = new ConfigurationBuilder()
      .SetBasePath(Environment.CurrentDirectory)
      .AddJsonFile("appsettings.Development.json")
      .Build();

    foreach (var envVariable in configs.AsEnumerable())
    {
        if (!string.IsNullOrEmpty(envVariable.Value))
        {
            Environment.SetEnvironmentVariable(envVariable.Key, envVariable.Value);
        }
    }
}

app.UseHttpsRedirection();

// Add trace enrichment middleware
app.UseTraceEnrichment();

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

// Map health check endpoints
app.MapHealthChecks("/health", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = HealthCheckResponseWriter.WriteJsonResponse
});
app.MapHealthChecks("/health/ready");
app.MapHealthChecks("/health/live");

app.Run();
