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
            // Configure for typical microservice scenarios
            http.AddStandardResilienceHandler(options =>
            {
                options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(600);
                options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(600);
                options.Retry.MaxRetryAttempts = 3;
                options.Retry.BackoffType = Polly.DelayBackoffType.Exponential;
                options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(1200); // Changed from 600 to 1200 (at least 2x AttemptTimeout)
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
                    });
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
        ArgumentNullException.ThrowIfNull(builder);

        builder.Services.AddHealthChecks()
            .AddCheck("self", () => HealthCheckResult.Healthy("Application is running"), ["live", "ready"]);

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
                    logger.LogWarning(
                        "Configuration key '{MessagingHostKey}' is not set. Service Bus client will not be available.",
                        MessagingHostConfigKey);

                    // Return a null client or throw based on environment
                    if (builder.Environment.IsDevelopment())
                    {
                        logger.LogWarning("Returning null ServiceBusClient for development environment");
                        return null!; // Allow null in development
                    }

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
                        logger.LogWarning("Service Bus emulator connection string not configured");
                        return null!;
                    }

                    logger.LogInformation("Configuring Service Bus client for local emulator mode");
                    return new ServiceBusClient(connectionString);
                }

                // Azure mode with managed identity
                logger.LogInformation("Configuring Service Bus client for Azure with managed identity. HostName: {HostName}", messagingHostName);

                var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    // Add timeout to prevent hanging
                    Retry = {
                        MaxRetries = 3,
                        NetworkTimeout = TimeSpan.FromSeconds(30)
                    },
                    ExcludeEnvironmentCredential = false,
                    ExcludeManagedIdentityCredential = false,
                    ExcludeSharedTokenCacheCredential = true,
                    ExcludeVisualStudioCredential = true,
                    ExcludeVisualStudioCodeCredential = true,
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
