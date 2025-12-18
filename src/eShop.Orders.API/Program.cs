// ------------------------------------------------------------------------------
// <copyright file="Program.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Application entry point for the Orders API.
//     Configures services, middleware, and endpoints for order processing.
// </summary>
// ------------------------------------------------------------------------------

using eShop.Orders.API.Middleware;
using eShop.Orders.API.Services;
using System.Diagnostics;

// Static ActivitySource for application startup tracing
// Persists for the application lifetime to ensure proper trace correlation
var startupActivitySource = new ActivitySource("eShop.Orders.Startup");

// Create activity for application startup tracing
using var startupActivity = startupActivitySource.StartActivity("Application.Startup", ActivityKind.Internal);

startupActivity?.SetTag("service.name", "eShop.Orders.API");
startupActivity?.SetTag("deployment.environment", Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown");

var builder = WebApplication.CreateBuilder(args);

// Add service defaults: OpenTelemetry instrumentation, health checks, service discovery, and resilience
using (var configActivity = startupActivitySource.StartActivity("Application.ConfigureServices", ActivityKind.Internal))
{
    configActivity?.SetTag("configuration.step", "service_defaults");
    builder.AddServiceDefaults();

    // Register MVC controllers for RESTful API endpoints
    configActivity?.SetTag("configuration.step", "mvc_controllers");
    builder.Services.AddControllers();

    // Add API documentation support via Swagger/OpenAPI
    // Only registered in development for security
    if (builder.Environment.IsDevelopment())
    {
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddOpenApi();
        builder.Services.AddSwaggerGen();
    }

    // Register order service as singleton for in-memory storage
    // Singleton is appropriate here because:
    // - Uses thread-safe ConcurrentDictionary for storage
    // - ServiceBusSender is thread-safe and reusable
    // - In-memory storage should persist across requests
    // - Implements IAsyncDisposable to properly release Service Bus resources on shutdown
    // Note: In production with a database, use AddScoped instead for proper DbContext management
    builder.Services.AddSingleton<IOrderService, OrderService>();

    // Register Azure Service Bus client using Aspire integration (if configured)
    // Provides automatic health checks, telemetry, and configuration management
    // Connection name "messaging" maps to the Service Bus resource defined in AppHost
    var messagingConnectionString = builder.Configuration.GetConnectionString("messaging");
    if (!string.IsNullOrWhiteSpace(messagingConnectionString))
    {
        builder.AddAzureServiceBusClient("messaging");
        // Register background service for continuous message processing from Service Bus
        builder.Services.AddHostedService<OrderMessageHandler>();
    }
    // Service Bus configuration is optional - application will log warning when OrderMessageHandler starts

    // Configure CORS to allow Blazor WebAssembly client requests
    // Uses Aspire service discovery for automatic origin resolution
    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            if (builder.Environment.IsDevelopment())
            {
                // Allow all origins in development for easier testing
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            }
            else
            {
                // In production, use Aspire service discovery to resolve allowed origins
                var allowedOrigins = new List<string>();

                // Try to resolve orders-webapp origin from Aspire service discovery
                var webAppOrigin = builder.Configuration["services:orders-webapp:https:0"]
                    ?? builder.Configuration["services:orders-webapp:http:0"];

                if (!string.IsNullOrEmpty(webAppOrigin))
                {
                    allowedOrigins.Add(webAppOrigin);
                }

                // Also check appsettings.json for additional origins
                var configuredOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();
                if (configuredOrigins?.Length > 0)
                {
                    allowedOrigins.AddRange(configuredOrigins);
                }

                if (allowedOrigins.Count > 0)
                {
                    policy.WithOrigins([.. allowedOrigins])
                          .AllowAnyMethod()
                          .AllowAnyHeader()
                          .AllowCredentials();
                }
                else
                {
                    // WARNING: Fallback to permissive policy if no origins configured
                    // This should be fixed in production by configuring proper allowed origins
                    // Using Console.WriteLine to avoid building ServiceProvider during configuration
                    Console.WriteLine(
                        "WARNING: CORS configuration is missing. Using permissive policy. " +
                        "Configure 'Cors:AllowedOrigins' in appsettings for production.");

                    policy.AllowAnyOrigin()
                          .AllowAnyMethod()
                          .AllowAnyHeader();
                }
            }
        });
    });

    configActivity?.AddEvent(new ActivityEvent("Services configured successfully"));
}

using (var buildActivity = startupActivitySource.StartActivity("Application.Build", ActivityKind.Internal))
{
    var app = builder.Build();
    buildActivity?.AddEvent(new ActivityEvent("Application built successfully"));

    using (var middlewareActivity = startupActivitySource.StartActivity("Application.ConfigureMiddleware", ActivityKind.Internal))
    {
        // Map health check endpoints FIRST for container orchestration probes
        // Health checks must respond on HTTP without HTTPS redirect
        // Used by load balancers and container orchestrators (Kubernetes, Container Apps)
        app.MapDefaultEndpoints();

        // Enable OpenAPI/Swagger UI only in development for security
        if (app.Environment.IsDevelopment())
        {
            middlewareActivity?.SetTag("configuration.step", "openapi");
            app.MapOpenApi();
            app.UseSwagger();
            app.UseSwaggerUI(options =>
            {
                options.SwaggerEndpoint("/openapi/v1.json", "eShop.Orders.API v1");
                options.RoutePrefix = string.Empty; // Serve Swagger UI at application root (http://localhost:port/)
            });
        }

        // Add correlation ID middleware early in pipeline
        // Ensures all subsequent middleware and logging operations have access to correlation ID
        app.UseCorrelationId();

        // HTTPS redirection is handled differently based on environment
        // In development: Redirect to HTTPS for local testing
        // In production/container environments: Ingress/load balancer handles HTTPS termination
        if (app.Environment.IsDevelopment())
        {
            app.UseHttpsRedirection();
        }

        // Enable CORS before authorization to ensure preflight requests are handled correctly
        app.UseCors();

        // Enable authorization middleware (currently configured but not enforcing policies)
        app.UseAuthorization();

        // Map API controllers to handle HTTP requests
        middlewareActivity?.SetTag("configuration.step", "map_controllers");
        app.MapControllers();

        middlewareActivity?.AddEvent(new ActivityEvent("Middleware configured successfully"));
    }

    startupActivity?.SetStatus(ActivityStatusCode.Ok);
    startupActivity?.AddEvent(new ActivityEvent("Application startup completed"));

    app.Run();
}