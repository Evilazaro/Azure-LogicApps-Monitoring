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

/// <summary>
/// Provides extension methods for configuring common Aspire services including
/// service discovery, resilience, health checks, and comprehensive OpenTelemetry instrumentation.
/// </summary>
/// <remarks>
/// This project should be referenced by each service project in your solution to ensure
/// consistent observability, resilience patterns, and service discovery configuration.
/// For more information, see https://aka.ms/dotnet/aspire/service-defaults
/// </remarks>
public static class Extensions
{
    #region Constants

    private const string HealthEndpointPath = "/health";
    private const string AlivenessEndpointPath = "/alive";
    private const string LiveHealthCheckTag = "live";
    private const string ServiceNamespace = "eShop.Orders";

    /// <summary>
    /// Activity source name for custom application spans.
    /// Use this constant when creating custom activities throughout the application
    /// to ensure proper trace correlation and filtering.
    /// </summary>
    /// <example>
    /// <code>
    /// using var activity = activitySource.StartActivity("ProcessOrder", ActivityKind.Internal);
    /// activity?.SetTag("order.id", orderId);
    /// activity?.SetTag("order.total", total);
    /// </code>
    /// </example>
    public const string ApplicationActivitySourceName = "eShop.Orders";

    #endregion

    #region Service Defaults Configuration

    /// <summary>
    /// Adds default Aspire services including OpenTelemetry, health checks, service discovery, and resilience patterns.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type (WebApplicationBuilder or HostApplicationBuilder).</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    /// <exception cref="ArgumentNullException">Thrown when builder is null.</exception>
    /// <remarks>
    /// This method configures the following features:
    /// <list type="bullet">
    /// <item>OpenTelemetry with distributed tracing, metrics, and logging</item>
    /// <item>Health checks with liveness and readiness probes</item>
    /// <item>Service discovery for inter-service communication</item>
    /// <item>Standard resilience handlers with retry, circuit breaker, and timeout policies</item>
    /// </list>
    /// </remarks>
    public static TBuilder AddServiceDefaults<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ConfigureOpenTelemetry();
        builder.AddDefaultHealthChecks();
        builder.AddServiceDiscoveryWithResilience();

        return builder;
    }

    /// <summary>
    /// Configures service discovery with resilience patterns for HTTP client communication.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    private static TBuilder AddServiceDiscoveryWithResilience<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        builder.Services.AddServiceDiscovery();

        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            // Apply standard resilience handler with:
            // - Retry policy: 3 attempts with exponential backoff
            // - Circuit breaker: Opens after 5 consecutive failures
            // - Timeout: 30 seconds per request
            http.AddStandardResilienceHandler();

            // Enable service discovery for all HTTP clients
            // Resolves service names to endpoints automatically
            http.AddServiceDiscovery();
        });

        // Optional: Restrict allowed schemes for security
        // Uncomment to enforce HTTPS-only communication in production
        // builder.Services.Configure<ServiceDiscoveryOptions>(options =>
        // {
        //     options.AllowedSchemes = ["https"];
        // });

        return builder;
    }

    #endregion

    #region OpenTelemetry Configuration

    /// <summary>
    /// Configures comprehensive OpenTelemetry instrumentation including metrics, traces, and logs
    /// with distributed tracing context propagation following W3C Trace Context specification.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    /// <exception cref="ArgumentNullException">Thrown when builder is null.</exception>
    /// <remarks>
    /// This method configures:
    /// <list type="bullet">
    /// <item>Structured logging with formatted messages and scopes</item>
    /// <item>Resource attributes including service name, version, and environment</item>
    /// <item>Metrics for ASP.NET Core, HTTP clients, and .NET runtime</item>
    /// <item>Distributed tracing with automatic instrumentation and custom enrichment</item>
    /// <item>Environment-specific sampling strategies (always-on for dev, ratio-based for prod)</item>
    /// <item>Exporters for OTLP (Aspire Dashboard) and Azure Monitor (Application Insights)</item>
    /// </list>
    /// </remarks>
    public static TBuilder ConfigureOpenTelemetry<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        ConfigureLogging(builder);
        ConfigureResourceAttributes(builder);

        builder.Services.AddOpenTelemetry()
            .WithMetrics(metrics => ConfigureMetrics(metrics, builder))
            .WithTracing(tracing => ConfigureTracing(tracing, builder));

        builder.AddOpenTelemetryExporters();

        return builder;
    }

    /// <summary>
    /// Configures structured logging with OpenTelemetry integration.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    private static void ConfigureLogging<TBuilder>(TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        builder.Logging.AddOpenTelemetry(logging =>
        {
            // Include formatted message for better readability in Application Insights
            // Example: "Order {OrderId} processed successfully" instead of template
            logging.IncludeFormattedMessage = true;

            // Include log scopes for contextual information
            // Captures user ID, correlation ID, tenant ID, etc.
            logging.IncludeScopes = true;
        });
    }

    /// <summary>
    /// Configures OpenTelemetry resource attributes for service identification and filtering.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    private static void ConfigureResourceAttributes<TBuilder>(TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        var serviceVersion = typeof(Extensions).Assembly.GetName().Version?.ToString() ?? "1.0.0";

        builder.Services.ConfigureOpenTelemetryTracerProvider(tracerProvider =>
        {
            tracerProvider.ConfigureResource(resource =>
            {
                // Set service identification attributes
                // These appear in Application Insights Application Map and dependency graphs
                resource.AddService(
                    serviceName: builder.Environment.ApplicationName,
                    serviceVersion: serviceVersion,
                    serviceInstanceId: Environment.MachineName);

                // Add custom attributes for filtering and grouping
                resource.AddAttributes(new Dictionary<string, object>
                {
                    ["deployment.environment"] = builder.Environment.EnvironmentName,
                    ["service.namespace"] = ServiceNamespace,
                    ["host.name"] = Environment.MachineName,
                    ["process.id"] = Environment.ProcessId
                });
            });
        });
    }

    /// <summary>
    /// Configures OpenTelemetry metrics collection for performance monitoring.
    /// </summary>
    /// <param name="metrics">The metrics builder to configure.</param>
    /// <param name="builder">The host application builder instance.</param>
    private static void ConfigureMetrics<TBuilder>(
        MeterProviderBuilder metrics,
        TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        // ASP.NET Core metrics: request duration, active requests, failed requests
        metrics.AddAspNetCoreInstrumentation();

        // HTTP client metrics: outbound request duration, failures, retries
        metrics.AddHttpClientInstrumentation();

        // .NET runtime metrics: GC collections, thread pool utilization, exception counts
        // Also includes process metrics: CPU usage, memory consumption, thread count
        metrics.AddRuntimeInstrumentation();

        // Add custom application metrics meter
        metrics.AddMeter(ApplicationActivitySourceName);
    }

    /// <summary>
    /// Configures OpenTelemetry distributed tracing with automatic instrumentation and enrichment.
    /// </summary>
    /// <param name="tracing">The tracing builder to configure.</param>
    /// <param name="builder">The host application builder instance.</param>
    private static void ConfigureTracing<TBuilder>(
        TracerProviderBuilder tracing,
        TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        // Add activity sources for custom span creation
        tracing.AddSource(ApplicationActivitySourceName);
        tracing.AddSource(builder.Environment.ApplicationName);

        // Configure ASP.NET Core instrumentation with custom enrichment
        ConfigureAspNetCoreTracing(tracing);

        // Configure HTTP client instrumentation with custom enrichment
        ConfigureHttpClientTracing(tracing);

        // Add Azure Service Bus instrumentation for messaging tracing
        tracing.AddSource("Azure.Messaging.ServiceBus.*");

        // Configure sampling strategy based on environment
        ConfigureSampling(tracing, builder);
    }

    /// <summary>
    /// Configures ASP.NET Core tracing instrumentation with request/response enrichment.
    /// </summary>
    /// <param name="tracing">The tracing builder to configure.</param>
    private static void ConfigureAspNetCoreTracing(TracerProviderBuilder tracing)
    {
        tracing.AddAspNetCoreInstrumentation(options =>
        {
            // Exclude health check endpoints from traces to reduce noise
            options.Filter = context =>
                !context.Request.Path.StartsWithSegments(HealthEndpointPath)
                && !context.Request.Path.StartsWithSegments(AlivenessEndpointPath);

            // Enrich spans with HTTP request details
            options.EnrichWithHttpRequest = (activity, httpRequest) =>
            {
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

            // Enrich spans with HTTP response details
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
                activity.SetTag("exception.type", exception.GetType().FullName);
                activity.SetTag("exception.message", exception.Message);
                activity.SetTag("exception.stacktrace", exception.StackTrace);

                // Add inner exception if present
                if (exception.InnerException is not null)
                {
                    activity.SetTag("exception.inner.type", exception.InnerException.GetType().FullName);
                    activity.SetTag("exception.inner.message", exception.InnerException.Message);
                }
            };

            // Record all exceptions as events in the span
            options.RecordException = true;
        });
    }

    /// <summary>
    /// Configures HTTP client tracing instrumentation with request/response enrichment.
    /// </summary>
    /// <param name="tracing">The tracing builder to configure.</param>
    private static void ConfigureHttpClientTracing(TracerProviderBuilder tracing)
    {
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
            options.FilterHttpRequestMessage = httpRequestMessage =>
                !httpRequestMessage.RequestUri?.PathAndQuery.Contains("/health") ?? true;
        });
    }

    /// <summary>
    /// Configures trace sampling strategy based on deployment environment.
    /// </summary>
    /// <param name="tracing">The tracing builder to configure.</param>
    /// <param name="builder">The host application builder instance.</param>
    /// <remarks>
    /// In production, uses parent-based sampling with 10% ratio to reduce costs.
    /// In non-production environments, always samples for debugging purposes.
    /// </remarks>
    private static void ConfigureSampling<TBuilder>(
        TracerProviderBuilder tracing,
        TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        if (builder.Environment.IsProduction())
        {
            // Parent-based sampler: always sample if parent is sampled, otherwise use ratio
            // This ensures complete traces for sampled requests while reducing volume
            tracing.SetSampler(new ParentBasedSampler(
                new TraceIdRatioBasedSampler(0.1))); // Sample 10% of traces in production
        }
        else
        {
            // Always sample in non-production environments for debugging
            tracing.SetSampler(new AlwaysOnSampler());
        }
    }

    #endregion

    #region OpenTelemetry Exporters

    /// <summary>
    /// Configures OpenTelemetry exporters based on environment configuration.
    /// Supports OTLP exporter for Aspire Dashboard (local development) and
    /// Azure Monitor exporter for Application Insights (production).
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    /// <remarks>
    /// Exporters are configured based on environment variables:
    /// <list type="bullet">
    /// <item>OTEL_EXPORTER_OTLP_ENDPOINT - Enables OTLP exporter (Aspire Dashboard)</item>
    /// <item>APPLICATIONINSIGHTS_CONNECTION_STRING - Enables Azure Monitor exporter</item>
    /// </list>
    /// </remarks>
    private static TBuilder AddOpenTelemetryExporters<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        var otlpEndpoint = builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"];
        var useOtlpExporter = !string.IsNullOrWhiteSpace(otlpEndpoint);

        if (useOtlpExporter)
        {
            // OTLP exporter for local development with Aspire Dashboard
            // Sends telemetry over gRPC to the dashboard for real-time visualization
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }

        var appInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
        if (!string.IsNullOrWhiteSpace(appInsightsConnectionString))
        {
            // Azure Monitor exporter for Application Insights in Azure environments
            builder.Services.AddOpenTelemetry()
               .UseAzureMonitor(options =>
               {
                   // Connection string is automatically read from configuration
                   // The configured sampler in tracing will be respected by Azure Monitor
               });
        }

        return builder;
    }

    #endregion

    #region Health Checks

    /// <summary>
    /// Adds default health checks for service monitoring and orchestration.
    /// Health checks are used by Container Apps, Kubernetes, and Azure Load Balancers
    /// to determine service readiness and liveness.
    /// </summary>
    /// <typeparam name="TBuilder">The host application builder type.</typeparam>
    /// <param name="builder">The host application builder instance.</param>
    /// <returns>The configured builder for method chaining.</returns>
    /// <exception cref="ArgumentNullException">Thrown when builder is null.</exception>
    /// <remarks>
    /// Configures a default "self" health check tagged as "live" for liveness probes.
    /// Additional health checks (database, message queue, etc.) should be added by individual services.
    /// </remarks>
    public static TBuilder AddDefaultHealthChecks<TBuilder>(this TBuilder builder)
        where TBuilder : IHostApplicationBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.Services.AddHealthChecks()
            // Add default liveness check to ensure app is responsive
            // This is used by orchestrators to determine if the app should be restarted
            .AddCheck("self", () => HealthCheckResult.Healthy(), [LiveHealthCheckTag]);

        return builder;
    }

    /// <summary>
    /// Maps health check endpoints with distributed tracing integration.
    /// Endpoints are only exposed in development environments for security.
    /// </summary>
    /// <param name="app">The web application instance.</param>
    /// <returns>The configured web application for method chaining.</returns>
    /// <exception cref="ArgumentNullException">Thrown when app is null.</exception>
    /// <remarks>
    /// <para>
    /// Exposes two endpoints in development:
    /// <list type="bullet">
    /// <item>/health - All health checks must pass (readiness probe)</item>
    /// <item>/alive - Only "live" tagged checks must pass (liveness probe)</item>
    /// </list>
    /// </para>
    /// <para>
    /// WARNING: Adding health checks endpoints in non-development environments has security implications.
    /// See https://aka.ms/dotnet/aspire/healthchecks for details before enabling in production.
    /// </para>
    /// </remarks>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        ArgumentNullException.ThrowIfNull(app);

        if (app.Environment.IsDevelopment())
        {
            // All health checks must pass for app to be considered ready to accept traffic
            app.MapHealthChecks(HealthEndpointPath);

            // Only health checks tagged with "live" must pass for app to be considered alive
            app.MapHealthChecks(AlivenessEndpointPath, new HealthCheckOptions
            {
                Predicate = healthCheck => healthCheck.Tags.Contains(LiveHealthCheckTag)
            });
        }

        return app;
    }

    #endregion

    #region Activity Source Helper

    /// <summary>
    /// Creates an ActivitySource for custom application tracing.
    /// Use this when you need to create custom spans for business logic or complex operations.
    /// </summary>
    /// <returns>An ActivitySource configured with the application name.</returns>
    /// <remarks>
    /// <para>
    /// The returned ActivitySource should be stored as a static field or singleton
    /// and reused throughout the application lifecycle. Do not create multiple instances.
    /// </para>
    /// <para>
    /// <strong>Best Practices for Distributed Tracing:</strong>
    /// </para>
    /// <list type="bullet">
    /// <item>
    /// <term>ActivitySource Lifecycle</term>
    /// <description>Store as static readonly field, never create per-request or in constructors</description>
    /// </item>
    /// <item>
    /// <term>Activity Naming</term>
    /// <description>Use format: ComponentName.OperationName (e.g., "OrderService.SendMessage")</description>
    /// </item>
    /// <item>
    /// <term>Activity Kind</term>
    /// <description>
    /// - Internal: Business logic operations
    /// - Client: Outbound HTTP/gRPC calls
    /// - Server: Inbound HTTP/gRPC requests (automatic)
    /// - Producer: Message publishing to queues/topics
    /// - Consumer: Message processing from queues/topics
    /// </description>
    /// </item>
    /// <item>
    /// <term>Semantic Tags</term>
    /// <description>Use standard semantic conventions (http.*, db.*, messaging.*) for consistent telemetry</description>
    /// </item>
    /// <item>
    /// <term>Status &amp; Events</term>
    /// <description>Always set status (Ok/Error) and add meaningful events for debugging</description>
    /// </item>
    /// <item>
    /// <term>Exception Recording</term>
    /// <description>Use activity?.AddException(ex) to capture full exception details in telemetry</description>
    /// </item>
    /// <item>
    /// <term>W3C Trace Context</term>
    /// <description>For messaging, propagate activity.Id as "traceparent" header for end-to-end correlation</description>
    /// </item>
    /// </list>
    /// <para>
    /// Example usage patterns:
    /// <code>
    /// // 1. Basic internal operation tracing
    /// private static readonly ActivitySource ActivitySource = Extensions.CreateActivitySource();
    /// 
    /// public async Task ProcessOrderAsync(string orderId)
    /// {
    ///     using var activity = ActivitySource.StartActivity("ProcessOrder", ActivityKind.Internal);
    ///     activity?.SetTag("order.id", orderId);
    ///     activity?.SetTag("order.source", "api");
    ///     
    ///     try
    ///     {
    ///         await ValidateOrderAsync(orderId);
    ///         await SaveOrderAsync(orderId);
    ///         
    ///         activity?.SetStatus(ActivityStatusCode.Ok);
    ///         activity?.AddEvent(new ActivityEvent("Order processed successfully"));
    ///     }
    ///     catch (Exception ex)
    ///     {
    ///         activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
    ///         activity?.AddException(ex);
    ///         throw;
    ///     }
    /// }
    /// 
    /// // 2. Service Bus message producer with trace context propagation
    /// using var activity = ActivitySource.StartActivity("SendMessage", ActivityKind.Producer);
    /// activity?.SetTag("messaging.system", "servicebus");
    /// activity?.SetTag("messaging.destination", "orders-queue");
    /// 
    /// var message = new ServiceBusMessage(body);
    /// // Propagate W3C Trace Context
    /// if (activity != null)
    /// {
    ///     message.ApplicationProperties.Add("traceparent", activity.Id);
    ///     message.ApplicationProperties.Add("TraceId", activity.TraceId.ToString());
    /// }
    /// await sender.SendMessageAsync(message);
    /// 
    /// // 3. Service Bus message consumer extracting trace context
    /// var traceparent = message.ApplicationProperties.TryGetValue("traceparent", out var tp) 
    ///     ? tp?.ToString() : null;
    /// using var activity = ActivitySource.StartActivity(
    ///     "ProcessMessage", 
    ///     ActivityKind.Consumer, 
    ///     traceparent ?? Activity.Current?.Id ?? string.Empty);
    /// </code>
    /// </para>
    /// </remarks>
    public static ActivitySource CreateActivitySource()
    {
        return new ActivitySource(ApplicationActivitySourceName);
    }

    #endregion
}