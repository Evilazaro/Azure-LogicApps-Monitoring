// =============================================================================
// Service Defaults Extensions
// =============================================================================
// 
// Purpose:
//   Provides cross-cutting concerns for .NET Aspire services including
//   OpenTelemetry instrumentation, health checks, service discovery, and
//   resilience patterns for distributed microservices architecture.
//
// Key Features:
//   - OpenTelemetry: Distributed tracing, metrics, and logging with support
//     for OTLP and Azure Monitor exporters
//   - Health Checks: Kubernetes/Azure Container Apps compatible health and
//     liveness endpoints (/health, /alive)
//   - Service Discovery: Automatic service discovery for HTTP clients
//   - Resilience: Retry policies, circuit breakers, and timeout handling
//   - Azure Service Bus: Configurable client with managed identity support
//
// Usage:
//   <code>
//   var builder = WebApplication.CreateBuilder(args);
//   builder.AddServiceDefaults();
//   builder.AddAzureServiceBusClient(); // Optional
//   var app = builder.Build();
//   app.MapDefaultEndpoints();
//   </code>
//
// Configuration:
//   - OTEL_EXPORTER_OTLP_ENDPOINT: OpenTelemetry collector endpoint
//   - APPLICATIONINSIGHTS_CONNECTION_STRING: Azure Monitor connection
//   - MESSAGING_HOST: Service Bus namespace or "localhost" for emulator
//   - ConnectionStrings:messaging: Local emulator connection string
//
// Dependencies:
//   - Azure.Identity: For managed identity authentication
//   - Azure.Messaging.ServiceBus: For Service Bus client
//   - Azure.Monitor.OpenTelemetry.Exporter: For Azure Monitor integration
//   - OpenTelemetry: For distributed tracing and metrics
//   - Microsoft.Extensions.Http.Resilience: For HTTP resilience policies
//
// =============================================================================

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
        ArgumentNullException.ThrowIfNull(builder);

        builder.ConfigureOpenTelemetry();

        builder.AddDefaultHealthChecks();

        builder.Services.AddServiceDiscovery();

        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            // Add resilience handler with retry, timeout, and circuit breaker policies
            // Best Practice: Configure resilience patterns for distributed systems
            // - TotalRequestTimeout: Maximum time for entire request including retries
            // - AttemptTimeout: Maximum time for each individual attempt
            // - Retry: Exponential backoff with jitter for transient failures
            // - CircuitBreaker: Prevents cascading failures by failing fast
            http.AddStandardResilienceHandler(options =>
            {
                options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(600);
                options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(60);
                options.Retry.MaxRetryAttempts = 3;
                options.Retry.BackoffType = Polly.DelayBackoffType.Exponential;
                // CircuitBreaker SamplingDuration must be at least 2x AttemptTimeout
                options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(120);
            });

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
        ArgumentNullException.ThrowIfNull(builder);

        builder.Logging.AddOpenTelemetry(logging =>
        {
            logging.IncludeFormattedMessage = true;
            logging.IncludeScopes = true;
            logging.ParseStateValues = true;
        });

        var openTelemetry = builder.Services.AddOpenTelemetry();

        openTelemetry.WithMetrics(metrics =>
        {
            metrics.AddAspNetCoreInstrumentation()
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation()
                .AddMeter(builder.Environment.ApplicationName)
                .AddMeter("eShop.Orders.API")
                .AddMeter("eShop.Web.App");
        });

        openTelemetry.WithTracing(tracing =>
        {
            tracing.AddSource(builder.Environment.ApplicationName)
                .AddSource("eShop.Orders.API")
                .AddSource("eShop.Web.App")
                .AddSource("Azure.Messaging.ServiceBus")
                .AddAspNetCoreInstrumentation(options =>
                {
                    options.Filter = context =>
                        !context.Request.Path.StartsWithSegments(HealthEndpointPath)
                        && !context.Request.Path.StartsWithSegments(AlivenessEndpointPath);
                    options.RecordException = true;
                    options.EnrichWithHttpRequest = (activity, httpRequest) =>
                    {
                        activity.SetTag("http.request.size", httpRequest.ContentLength ?? 0);
                    };
                    options.EnrichWithHttpResponse = (activity, httpResponse) =>
                    {
                        activity.SetTag("http.response.size", httpResponse.ContentLength ?? 0);
                    };
                })
                .AddHttpClientInstrumentation(options =>
                {
                    options.RecordException = true;
                    options.EnrichWithHttpRequestMessage = (activity, httpRequest) =>
                    {
                        activity.SetTag("http.request.method", httpRequest.Method.ToString());
                    };
                })
                .AddSqlClientInstrumentation(options =>
                {
                    options.RecordException = true;
                });
        });

        AddOpenTelemetryExporters(builder, openTelemetry);

        return builder;
    }

    /// <summary>
    /// Adds OpenTelemetry exporters (OTLP and Azure Monitor) based on configuration.
    /// </summary>
    /// <typeparam name="TBuilder">The type of host application builder.</typeparam>
    /// <param name="builder">The host application builder to configure.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    private static void AddOpenTelemetryExporters(IHostApplicationBuilder builder, OpenTelemetryBuilder openTelemetry)
    {
        ArgumentNullException.ThrowIfNull(builder);
        ArgumentNullException.ThrowIfNull(openTelemetry);

        var useOtlpExporter = !string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]);

        if (useOtlpExporter)
        {
            openTelemetry.UseOtlpExporter();
        }

        var appInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
        if (!string.IsNullOrEmpty(appInsightsConnectionString))
        {
            // Add Azure Monitor exporters to the existing OpenTelemetry configuration
            openTelemetry
                .WithTracing(tracing => tracing.AddAzureMonitorTraceExporter(options =>
                {
                    options.ConnectionString = appInsightsConnectionString;
                }))
                .WithMetrics(metrics => metrics.AddAzureMonitorMetricExporter(options =>
                {
                    options.ConnectionString = appInsightsConnectionString;
                }));
        }
    }

    /// <summary>
    /// Adds default health checks including a self-check endpoint for liveness probes.
    /// </summary>
    /// <typeparam name="TBuilder">The type of host application builder.</typeparam>
    /// <param name="builder">The host application builder to configure.</param>
    /// <returns>The configured builder instance for method chaining.</returns>
    public static TBuilder AddDefaultHealthChecks<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.Services.AddHealthChecks()
            .AddCheck("self", () => HealthCheckResult.Healthy("Application is running"), tags: new[] { "live" });

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
                var messagingHostName = builder.Configuration[MessagingHostConfigKey];

                // Also check alternative configuration key
                if (string.IsNullOrWhiteSpace(messagingHostName))
                {
                    messagingHostName = builder.Configuration["Azure:ServiceBus:HostName"];
                }

                if (string.IsNullOrWhiteSpace(messagingHostName))
                {
                    throw new InvalidOperationException(
                        $"Configuration key '{MessagingHostConfigKey}' is required for Service Bus client initialization. " +
                        $"Please ensure this value is set in appsettings.json or user secrets.");
                }

                var connectionString = builder.Configuration[MessagingConnectionStringKey];

                // Local emulator mode
                if (messagingHostName.Equals(LocalhostValue, StringComparison.OrdinalIgnoreCase))
                {
                    if (string.IsNullOrWhiteSpace(connectionString))
                    {
                        throw new InvalidOperationException(
                            $"Configuration key '{MessagingConnectionStringKey}' is required when using local Service Bus emulator. " +
                            "Ensure the emulator resource is referenced so the connection string is provided.");
                    }

                    logger.LogInformation("Configuring Service Bus client for local emulator mode");
                    return new ServiceBusClient(connectionString);
                }

                // Azure mode with managed identity
                logger.LogInformation("Configuring Service Bus client for Azure with managed identity. HostName: {HostName}", messagingHostName);

                var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    Retry = {
                        MaxRetries = 3,
                        NetworkTimeout = TimeSpan.FromSeconds(30)
                    },
                    // Only use credential types that make sense for Azure environments
                    ExcludeEnvironmentCredential = false,
                    ExcludeManagedIdentityCredential = false,
                    ExcludeVisualStudioCredential = false,
                    ExcludeVisualStudioCodeCredential = false,
                    ExcludeAzureCliCredential = false,
                    ExcludeAzurePowerShellCredential = true,
                    ExcludeInteractiveBrowserCredential = true
                });

                var clientOptions = new ServiceBusClientOptions
                {
                    RetryOptions = new ServiceBusRetryOptions
                    {
                        MaxRetries = 3,
                        Delay = TimeSpan.FromSeconds(1),
                        MaxDelay = TimeSpan.FromSeconds(10),
                        Mode = ServiceBusRetryMode.Exponential
                    },
                    TransportType = ServiceBusTransportType.AmqpWebSockets // Better for firewall scenarios
                };

                return new ServiceBusClient(messagingHostName, credential, clientOptions);
            }
            catch (Exception ex)
            {
                logger.LogError(ex,
                    "Failed to create Service Bus client. Ensure configuration keys '{MessagingHostKey}' and '{ConnectionStringKey}' are properly set.",
                    MessagingHostConfigKey, MessagingConnectionStringKey);

                // In production, we need to fail fast to prevent the app from starting incorrectly
                throw;
            }
        });

        return builder;
    }

    /// <summary>
    /// Maps default health check endpoints for application health monitoring.
    /// Includes both general health endpoint and liveness endpoint.
    /// Health endpoints are exposed in all environments to support Azure Container Apps probes.
    /// </summary>
    /// <param name="app">The web application to configure.</param>
    /// <returns>The configured web application instance for method chaining.</returns>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        // Always expose health endpoints for container orchestration (Azure Container Apps, Kubernetes, etc.)
        app.MapHealthChecks(HealthEndpointPath);

        app.MapHealthChecks(AlivenessEndpointPath, new HealthCheckOptions
        {
            Predicate = r => r.Tags.Contains("live")
        });

        return app;
    }
}
