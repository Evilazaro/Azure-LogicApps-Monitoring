using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

// Configure comprehensive OpenTelemetry with Azure Monitor
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: "PoProcAPI",
            serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString() ?? "1.0.0",
            serviceInstanceId: Environment.MachineName)
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = builder.Environment.EnvironmentName,
            ["service.namespace"] = "eShopOrders",
            ["cloud.provider"] = "azure",
            ["cloud.platform"] = "azure_app_service",
            ["host.name"] = Environment.MachineName
        }))
    .WithTracing(tracing =>
    {
        tracing
            // ASP.NET Core instrumentation with detailed options
            .AddAspNetCoreInstrumentation(options =>
            {
                options.RecordException = true;
                options.EnrichWithHttpRequest = (activity, httpRequest) =>
                {
                    activity.SetTag("http.request.header.user_agent", httpRequest.Headers.UserAgent.ToString());
                    activity.SetTag("http.request.header.host", httpRequest.Host.ToString());
                    activity.SetTag("http.request.body.size", httpRequest.ContentLength ?? 0);
                };
                options.EnrichWithHttpResponse = (activity, httpResponse) =>
                {
                    activity.SetTag("http.response.status_code", httpResponse.StatusCode);
                    activity.SetTag("http.response.body.size", httpResponse.ContentLength ?? 0);
                };
                options.Filter = (httpContext) =>
                {
                    // Exclude health check and metrics endpoints from tracing
                    var path = httpContext.Request.Path.Value ?? string.Empty;
                    return !path.Contains("/health") && !path.Contains("/metrics");
                };
            })
            // HTTP Client instrumentation for outbound calls
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
            // Add custom activity sources
            .AddSource("PoProcAPI.*")
            .AddSource("Azure.*")
            // Use AlwaysOn sampler for complete trace collection
            .SetSampler(new AlwaysOnSampler());
    })
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation();
    })
    .UseAzureMonitor(options =>
    {
        options.ConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
    });

// Add Application Insights Telemetry for additional features
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
    options.EnableAdaptiveSampling = false; // Disable to use OpenTelemetry sampling
    options.EnableQuickPulseMetricStream = true; // Enable Live Metrics
});

// Configure logging with OpenTelemetry
builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
});

// Add health checks for monitoring
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();

    var configs = new ConfigurationBuilder()
       .SetBasePath(Environment.CurrentDirectory)
       .AddJsonFile("appsettings.Development.json")
       .Build();

    foreach (var envVariable in configs.AsEnumerable())
    {
        Environment.SetEnvironmentVariable(envVariable.Key, envVariable.Value);
    }
}

app.UseHttpsRedirection();
app.UseAuthorization();

// Map health check endpoint
app.MapHealthChecks("/health");

app.MapControllers();

app.Run();
