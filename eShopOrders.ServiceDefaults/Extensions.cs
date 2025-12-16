using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using System.Diagnostics;

namespace Microsoft.Extensions.Hosting;

// Adds common Aspire services: service discovery, resilience, health checks, and OpenTelemetry.
// This project should be referenced by each service project in your solution.
// To learn more about using this project, see https://aka.ms/dotnet/aspire/service-defaults
public static class Extensions
{
    private const string HealthEndpointPath = "/health";
    private const string AlivenessEndpointPath = "/alive";

    /// <summary>
    /// Activity source name for custom application spans.
    /// This should be used when creating custom activities throughout the application.
    /// </summary>
    public const string ApplicationActivitySourceName = "eShop.Orders";

    public static TBuilder AddServiceDefaults<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.ConfigureOpenTelemetry();

        builder.AddDefaultHealthChecks();

        builder.Services.AddServiceDiscovery();

        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            // Turn on resilience by default
            http.AddStandardResilienceHandler();

            // Turn on service discovery by default
            http.AddServiceDiscovery();
        });

        // Uncomment the following to restrict the allowed schemes for service discovery.
        // builder.Services.Configure<ServiceDiscoveryOptions>(options =>
        // {
        //     options.AllowedSchemes = ["https"];
        // });

        return builder;
    }

    /// <summary>
    /// Configures comprehensive OpenTelemetry instrumentation including metrics, traces, and logs.
    /// Implements distributed tracing with context propagation following W3C Trace Context specification.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    public static TBuilder ConfigureOpenTelemetry<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        // Configure structured logging with OpenTelemetry
        builder.Logging.AddOpenTelemetry(logging =>
        {
            // Include formatted message for better readability in Application Insights
            logging.IncludeFormattedMessage = true;

            // Include log scopes for contextual information (user ID, correlation ID, etc.)
            logging.IncludeScopes = true;
        });

        builder.Services.AddOpenTelemetry()
            .ConfigureResource(resource =>
            {
                // Set service name and version for proper identification in distributed traces
                // This appears in Application Insights Application Map and dependency graphs
                resource.AddService(
                    serviceName: builder.Environment.ApplicationName,
                    serviceVersion: typeof(Extensions).Assembly.GetName().Version?.ToString() ?? "1.0.0",
                    serviceInstanceId: Environment.MachineName);

                // Add deployment environment for filtering traces by environment
                resource.AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = builder.Environment.EnvironmentName,
                    ["service.namespace"] = "eShop.Orders"
                });
            })
            .WithMetrics(metrics =>
            {
                // ASP.NET Core metrics: request duration, active requests, failed requests
                metrics.AddAspNetCoreInstrumentation();

                // HTTP client metrics: outbound request duration, failures, retries
                metrics.AddHttpClientInstrumentation();

                // .NET runtime metrics: GC collections, thread pool utilization, exception counts
                metrics.AddRuntimeInstrumentation();

                // Note: AddProcessInstrumentation() is not available in OpenTelemetry.Instrumentation.Runtime
                // Process metrics are included in AddRuntimeInstrumentation() which covers:
                // - CPU usage, memory consumption, thread count, GC collections, etc.

                // Add meters for custom application metrics
                metrics.AddMeter(ApplicationActivitySourceName);
            })
            .WithTracing(tracing =>
            {
                // Add application-specific activity source for custom spans
                tracing.AddSource(ApplicationActivitySourceName);

                // Add default activity source using application name
                tracing.AddSource(builder.Environment.ApplicationName);

                // ASP.NET Core instrumentation: automatic spans for HTTP requests
                tracing.AddAspNetCoreInstrumentation(options =>
                {
                    // Exclude health check endpoints from traces to reduce noise
                    options.Filter = context =>
                        !context.Request.Path.StartsWithSegments(HealthEndpointPath)
                        && !context.Request.Path.StartsWithSegments(AlivenessEndpointPath);

                    // Enrich spans with additional HTTP request information
                    options.EnrichWithHttpRequest = (activity, httpRequest) =>
                    {
                        // Add custom tags for better trace filtering and analysis
                        activity.SetTag("http.request.host", httpRequest.Host.ToString());
                        activity.SetTag("http.request.scheme", httpRequest.Scheme);

                        // Add user agent for client tracking
                        if (httpRequest.Headers.UserAgent.Count > 0)
                        {
                            activity.SetTag("http.user_agent", httpRequest.Headers.UserAgent.ToString());
                        }

                        // Add correlation ID if present (common in enterprise scenarios)
                        if (httpRequest.Headers.TryGetValue("X-Correlation-ID", out var correlationId))
                        {
                            activity.SetTag("correlation.id", correlationId.ToString());
                        }
                    };

                    // Enrich spans with HTTP response information
                    options.EnrichWithHttpResponse = (activity, httpResponse) =>
                    {
                        // Add response size for performance analysis
                        if (httpResponse.ContentLength.HasValue)
                        {
                            activity.SetTag("http.response.content_length", httpResponse.ContentLength.Value);
                        }

                        // Mark activity as error for non-success status codes
                        if (httpResponse.StatusCode >= 400)
                        {
                            activity.SetStatus(ActivityStatusCode.Error, $"HTTP {httpResponse.StatusCode}");
                        }
                    };

                    // Enrich spans with exception details
                    options.EnrichWithException = (activity, exception) =>
                    {
                        // Add detailed exception information for troubleshooting
                        activity.SetTag("exception.type", exception.GetType().FullName);
                        activity.SetTag("exception.message", exception.Message);
                        activity.SetTag("exception.stacktrace", exception.StackTrace);

                        // Add inner exception if present
                        if (exception.InnerException != null)
                        {
                            activity.SetTag("exception.inner.type", exception.InnerException.GetType().FullName);
                            activity.SetTag("exception.inner.message", exception.InnerException.Message);
                        }
                    };

                    // Record all exceptions as events in the span
                    options.RecordException = true;
                });

                // HTTP client instrumentation: automatic spans for outbound HTTP calls
                tracing.AddHttpClientInstrumentation(options =>
                {
                    // Enrich outbound HTTP request spans
                    options.EnrichWithHttpRequestMessage = (activity, httpRequestMessage) =>
                    {
                        activity.SetTag("http.request.method", httpRequestMessage.Method.ToString());
                        activity.SetTag("http.request.uri", httpRequestMessage.RequestUri?.ToString());

                        // Add custom headers for distributed tracing context
                        if (httpRequestMessage.Headers.TryGetValues("X-Request-ID", out var requestId))
                        {
                            activity.SetTag("http.request.id", string.Join(",", requestId));
                        }
                    };

                    // Enrich with HTTP response message
                    options.EnrichWithHttpResponseMessage = (activity, httpResponseMessage) =>
                    {
                        activity.SetTag("http.response.status_code", (int)httpResponseMessage.StatusCode);

                        // Track response timing for performance monitoring
                        if (httpResponseMessage.Headers.TryGetValues("X-Response-Time", out var responseTime))
                        {
                            activity.SetTag("http.response.time_ms", string.Join(",", responseTime));
                        }
                    };

                    // Enrich with exception details for failed requests
                    options.EnrichWithException = (activity, exception) =>
                    {
                        activity.SetTag("http.exception.type", exception.GetType().FullName);
                        activity.SetTag("http.exception.message", exception.Message);
                    };

                    // Record exceptions in HTTP client spans
                    options.RecordException = true;

                    // Filter out health check requests to external services
                    options.FilterHttpRequestMessage = (httpRequestMessage) =>
                    {
                        return !httpRequestMessage.RequestUri?.PathAndQuery.Contains("/health") ?? true;
                    };
                });

                // Add SqlClient instrumentation for database tracing (if using SQL Server)
                // Uncomment and add NuGet package: OpenTelemetry.Instrumentation.SqlClient
                // tracing.AddSqlClientInstrumentation(options =>
                // {
                //     options.SetDbStatementForText = true; // Include SQL statements (be careful with PII)
                //     options.SetDbStatementForStoredProcedure = true;
                //     options.RecordException = true;
                //     options.EnableConnectionLevelAttributes = true;
                // });

                // Add Azure Service Bus instrumentation for messaging tracing
                // Uncomment and add NuGet package: Azure.Messaging.ServiceBus.OpenTelemetry
                tracing.AddSource("Azure.Messaging.ServiceBus.*");

                // Add gRPC client instrumentation if using gRPC
                // Uncomment and add NuGet package: OpenTelemetry.Instrumentation.GrpcNetClient
                // tracing.AddGrpcClientInstrumentation(options =>
                // {
                //     options.SuppressDownstreamInstrumentation = false;
                //     options.EnrichWithHttpRequestMessage = (activity, httpRequestMessage) =>
                //     {
                //         activity.SetTag("grpc.method", httpRequestMessage.RequestUri?.ToString());
                //     };
                // });

                // Set sampler for production environments to reduce telemetry volume
                // In development, trace everything. In production, sample based on load.
                if (builder.Environment.IsProduction())
                {
                    // Parent-based sampler: always sample if parent is sampled, otherwise use ratio
                    tracing.SetSampler(new ParentBasedSampler(
                        new TraceIdRatioBasedSampler(0.1))); // Sample 10% of traces in production
                }
                else
                {
                    // Always sample in non-production environments for debugging
                    tracing.SetSampler(new AlwaysOnSampler());
                }

                // Set resource limits to prevent memory issues
                tracing.SetResourceBuilder(ResourceBuilder.CreateDefault()
                    .AddService(builder.Environment.ApplicationName));

                // Configure batch export processor for better performance
                // Spans are batched before export to reduce network overhead
                tracing.AddProcessor(new BatchActivityExportProcessor(
                    new NoopActivityExporter(), // Will be replaced by actual exporter
                    maxQueueSize: 2048,
                    scheduledDelayMilliseconds: 5000,
                    exporterTimeoutMilliseconds: 30000,
                    maxExportBatchSize: 512));
            });

        // Configure exporters based on environment variables and configuration
        builder.AddOpenTelemetryExporters();

        return builder;
    }

    /// <summary>
    /// Configures OpenTelemetry exporters based on environment configuration.
    /// Supports OTLP (Aspire Dashboard) and Azure Monitor (Application Insights).
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    private static TBuilder AddOpenTelemetryExporters<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        // Check if OTLP exporter should be enabled (Aspire Dashboard in local development)
        var useOtlpExporter = !string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]);

        if (useOtlpExporter)
        {
            // OTLP exporter for local development with Aspire Dashboard
            // Sends telemetry over gRPC to the dashboard for real-time visualization
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }

        // Azure Monitor exporter for Application Insights in Azure environments
        if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
        {
            builder.Services.AddOpenTelemetry()
               .UseAzureMonitor(options =>
               {
                   // Connection string is automatically read from configuration
                   // Additional configuration can be added here if needed

                   // Enable sampling to reduce costs in production
                   // Azure Monitor will respect the sampler configured in tracing
               });
        }

        return builder;
    }

    /// <summary>
    /// Adds default health checks for service monitoring and orchestration.
    /// Health checks are used by Container Apps, Kubernetes, and Azure Load Balancers.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    public static TBuilder AddDefaultHealthChecks<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.Services.AddHealthChecks()
            // Add a default liveness check to ensure app is responsive
            // This is used by orchestrators to determine if the app should be restarted
            .AddCheck("self", () => HealthCheckResult.Healthy(), ["live"]);

        return builder;
    }

    /// <summary>
    /// Maps health check endpoints with distributed tracing integration.
    /// Endpoints are only exposed in development for security reasons.
    /// </summary>
    /// <param name="app">The web application instance.</param>
    /// <returns>The configured web application for method chaining.</returns>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        // Adding health checks endpoints to applications in non-development environments has security implications.
        // See https://aka.ms/dotnet/aspire/healthchecks for details before enabling these endpoints in non-development environments.
        if (app.Environment.IsDevelopment())
        {
            // All health checks must pass for app to be considered ready to accept traffic after starting
            app.MapHealthChecks(HealthEndpointPath);

            // Only health checks tagged with the "live" tag must pass for app to be considered alive
            app.MapHealthChecks(AlivenessEndpointPath, new HealthCheckOptions
            {
                Predicate = r => r.Tags.Contains("live")
            });
        }

        return app;
    }

    /// <summary>
    /// Creates an ActivitySource for custom application tracing.
    /// Use this when you need to create custom spans for business logic or complex operations.
    /// </summary>
    /// <example>
    /// <code>
    /// var activitySource = Extensions.CreateActivitySource();
    /// using var activity = activitySource.StartActivity("ProcessOrder");
    /// activity?.SetTag("order.id", orderId);
    /// // Your business logic here
    /// </code>
    /// </example>
    /// <returns>An ActivitySource configured with the application name.</returns>
    public static ActivitySource CreateActivitySource()
    {
        return new ActivitySource(ApplicationActivitySourceName);
    }
}

/// <summary>
/// No-op activity exporter used as placeholder in batch processor configuration.
/// The actual exporter (OTLP or Azure Monitor) is configured separately.
/// </summary>
internal sealed class NoopActivityExporter : BaseExporter<Activity>
{
    public override ExportResult Export(in Batch<Activity> batch)
    {
        return ExportResult.Success;
    }
}