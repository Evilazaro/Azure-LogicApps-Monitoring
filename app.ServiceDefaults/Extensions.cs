using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Azure.Monitor.OpenTelemetry.Exporter;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Microsoft.Extensions.Hosting;

/// <summary>
/// Provides extension methods for configuring common service defaults including OpenTelemetry,
/// health checks, service discovery, and Azure Service Bus integration.
/// </summary>
public static class Extensions
{
    private const string HealthEndpointPath = "/health";
    private const string AlivenessEndpointPath = "/alive";
    private const string MessagingHostConfigKey = "MESSAGING_HOST";
    private const string MessagingConnectionStringKey = "ConnectionStrings:messaging";
    private const string LocalhostValue = "localhost";

    /// <summary>
    /// Adds common service defaults including OpenTelemetry, health checks, and service discovery.
    /// </summary>
    /// <typeparam name="TBuilder">The type of host application builder.</typeparam>
    /// <param name="builder">The host application builder to configure.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    public static TBuilder AddServiceDefaults<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.ConfigureOpenTelemetry();

        builder.AddDefaultHealthChecks();

        builder.Services.AddServiceDiscovery();

        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            // Add resilience handler with retry, timeout, and circuit breaker policies
            http.AddStandardResilienceHandler();

            // Enable service discovery for HTTP clients
            http.AddServiceDiscovery();
        });

        return builder;
    }

    /// <summary>
    /// Configures OpenTelemetry for distributed tracing, metrics, and logging with proper instrumentation.
    /// </summary>
    /// <typeparam name="TBuilder">The type of host application builder.</typeparam>
    /// <param name="builder">The host application builder to configure.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    public static TBuilder ConfigureOpenTelemetry<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.Logging.AddOpenTelemetry(logging =>
        {
            logging.IncludeFormattedMessage = true;
            logging.IncludeScopes = true;
        });

        builder.Services.AddOpenTelemetry()
            .WithMetrics(metrics =>
            {
                metrics.AddAspNetCoreInstrumentation()
                    .AddHttpClientInstrumentation()
                    .AddRuntimeInstrumentation();
            })
            .WithTracing(tracing =>
            {
                tracing.AddSource(builder.Environment.ApplicationName)
                    .AddSource("eShop.Orders.API")
                    .AddSource("eShop.Web.App")
                    .AddAspNetCoreInstrumentation(options =>
                        options.Filter = context =>
                            !context.Request.Path.StartsWithSegments(HealthEndpointPath)
                            && !context.Request.Path.StartsWithSegments(AlivenessEndpointPath)
                    )
                    .AddHttpClientInstrumentation();
            });

        builder.AddOpenTelemetryExporters();

        return builder;
    }

    /// <summary>
    /// Adds OpenTelemetry exporters (OTLP and Azure Monitor) based on configuration.
    /// </summary>
    /// <typeparam name="TBuilder">The type of host application builder.</typeparam>
    /// <param name="builder">The host application builder to configure.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    private static TBuilder AddOpenTelemetryExporters<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        var useOtlpExporter = !string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]);

        if (useOtlpExporter)
        {
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }

        var appInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
        if (!string.IsNullOrEmpty(appInsightsConnectionString))
        {
            // Add Azure Monitor exporters to the existing OpenTelemetry configuration
            builder.Services.AddOpenTelemetry()
                .WithTracing(tracing => tracing.AddAzureMonitorTraceExporter(options =>
                {
                    options.ConnectionString = appInsightsConnectionString;
                }))
                .WithMetrics(metrics => metrics.AddAzureMonitorMetricExporter(options =>
                {
                    options.ConnectionString = appInsightsConnectionString;
                }));
        }

        return builder;
    }

    /// <summary>
    /// Adds default health checks including a self-check endpoint for liveness probes.
    /// </summary>
    /// <typeparam name="TBuilder">The type of host application builder.</typeparam>
    /// <param name="builder">The host application builder to configure.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    public static TBuilder AddDefaultHealthChecks<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.Services.AddHealthChecks()
            .AddCheck("self", () => HealthCheckResult.Healthy(), ["live"]);

        return builder;
    }

    /// <summary>
    /// Registers an Azure Service Bus client with automatic configuration for local emulator or Azure deployment.
    /// Supports both connection string authentication (local) and managed identity (Azure).
    /// </summary>
    /// <param name="builder">The host application builder.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    /// <exception cref="ArgumentNullException">Thrown when builder is null.</exception>
    /// <exception cref="InvalidOperationException">Thrown when required configuration is missing.</exception>
    public static IHostApplicationBuilder AddAzureServiceBusClient(this IHostApplicationBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.Services.AddSingleton<ServiceBusClient>(serviceProvider =>
        {
            var logger = serviceProvider.GetRequiredService<ILogger<ServiceBusClient>>();

            try
            {
                var messagingHostName = builder.Configuration[MessagingHostConfigKey]
                    ?? throw new InvalidOperationException($"{MessagingHostConfigKey} configuration is required for Service Bus client initialization");

                var connectionString = builder.Configuration[MessagingConnectionStringKey]
                    ?? throw new InvalidOperationException($"{MessagingConnectionStringKey} is required for Service Bus client initialization");


                if (messagingHostName.Equals(LocalhostValue, StringComparison.OrdinalIgnoreCase))
                {
                    logger.LogInformation("Configuring Service Bus client for local emulator mode");
                    return new ServiceBusClient(connectionString);
                }

                logger.LogInformation("Configuring Service Bus client for Azure with managed identity. HostName: {HostName}", messagingHostName);
                return new ServiceBusClient(messagingHostName, new DefaultAzureCredential());
            }
            catch (Exception ex)
            {
                logger.LogError(ex,
                    "Failed to create Service Bus client. Ensure configuration keys '{MessagingHostKey}' and '{ConnectionStringKey}' are properly set",
                    MessagingHostConfigKey, MessagingConnectionStringKey);
                throw;
            }
        });

        return builder;
    }

    /// <summary>
    /// Maps default health check endpoints for application health monitoring.
    /// Includes both general health endpoint and liveness endpoint.
    /// </summary>
    /// <param name="app">The web application to configure.</param>
    /// <returns>The configured web application instance for method chaining.</returns>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);
        
        if (app.Environment.IsDevelopment())
        {
            app.MapHealthChecks(HealthEndpointPath);

            app.MapHealthChecks(AlivenessEndpointPath, new HealthCheckOptions
            {
                Predicate = r => r.Tags.Contains("live")
            });
        }

        return app;
    }
}
