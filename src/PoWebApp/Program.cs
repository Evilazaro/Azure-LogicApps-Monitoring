using Azure.Monitor.OpenTelemetry.AspNetCore;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using PoWebApp.Components;
using PoWebApp.Diagnostics;
using Microsoft.ApplicationInsights;
using System.Diagnostics;

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
            [DiagnosticsConfig.SemanticConventions.CloudPlatform] = "azure_app_service"
        }))
    .WithTracing(tracing => tracing
        // Add ASP.NET Core instrumentation for automatic request tracking
        .AddAspNetCoreInstrumentation(options =>
        {
            options.RecordException = true;
            options.EnrichWithHttpRequest = (activity, httpRequest) =>
            {
                activity.SetTag("http.request.method", httpRequest.Method);
                activity.SetTag("http.request.path", httpRequest.Path);
            };
            options.EnrichWithHttpResponse = (activity, httpResponse) =>
            {
                activity.SetTag("http.response.status_code", httpResponse.StatusCode);
            };
        })
        // Add HTTP client instrumentation for automatic dependency tracking
        .AddHttpClientInstrumentation(options =>
        {
            options.RecordException = true;
            options.EnrichWithHttpRequestMessage = (activity, httpRequestMessage) =>
            {
                activity.SetTag("http.request.method", httpRequestMessage.Method.ToString());
            };
            options.EnrichWithHttpResponseMessage = (activity, httpResponseMessage) =>
            {
                activity.SetTag("http.response.status_code", (int)httpResponseMessage.StatusCode);
            };
        })
        // Add custom activity sources for business operations
        .AddSource(DiagnosticsConfig.ActivitySources.Orders.Name)
        .AddSource(DiagnosticsConfig.ActivitySources.UI.Name)
        .AddSource(DiagnosticsConfig.ActivitySources.Messaging.Name))
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
builder.Services.AddScoped<Orders>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();

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

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
