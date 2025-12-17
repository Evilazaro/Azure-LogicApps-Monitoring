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

// Create activity source for application startup tracing
using var startupActivity = new ActivitySource("eShop.Orders.Startup")
    .StartActivity("Application.Startup", ActivityKind.Internal);

startupActivity?.SetTag("service.name", "eShop.Orders.API");
startupActivity?.SetTag("deployment.environment", Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown");

var builder = WebApplication.CreateBuilder(args);

// Add service defaults: OpenTelemetry instrumentation, health checks, service discovery, and resilience
using (var configActivity = new ActivitySource("eShop.Orders.Startup")
    .StartActivity("Application.ConfigureServices", ActivityKind.Internal))
{
    configActivity?.SetTag("configuration.step", "service_defaults");
    builder.AddServiceDefaults();

    // Register MVC controllers for RESTful API endpoints
    configActivity?.SetTag("configuration.step", "mvc_controllers");
    builder.Services.AddControllers();

// Add API documentation support via Swagger/OpenAPI
// Enables automatic API schema generation and interactive documentation UI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen();

// Register order service as singleton for in-memory storage
// In production, this should be scoped with proper database context
// Note: ServiceBusClient is automatically registered by AddAzureServiceBusClient
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
else
{
    builder.Logging.AddConsole().Services.Configure<LoggerFilterOptions>(options =>
    {
        options.Rules.Add(new LoggerFilterRule(null, "Microsoft.Extensions.Hosting", LogLevel.Information, null));
    });
    var logger = LoggerFactory.Create(logging => logging.AddConsole()).CreateLogger("Startup");
    logger.LogWarning("Service Bus connection string 'messaging' not found. Message processing is disabled.");
}

// Configure CORS to allow Blazor WebAssembly client requests
// In production, restrict to specific origins
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            // Allow all in development
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
        else
        {
            // In production, restrict to specific origins from configuration
            var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
            if (allowedOrigins.Length > 0)
            {
                policy.WithOrigins(allowedOrigins)
                      .AllowAnyMethod()
                      .AllowAnyHeader()
                      .AllowCredentials();
            }
        }
    });
});

    configActivity?.AddEvent(new ActivityEvent("Services configured successfully"));
}

using (var buildActivity = new ActivitySource("eShop.Orders.Startup")
    .StartActivity("Application.Build", ActivityKind.Internal))
{
    var app = builder.Build();
    buildActivity?.AddEvent(new ActivityEvent("Application built successfully"));


    // Enable OpenAPI/Swagger UI only in development for security
    using (var middlewareActivity = new ActivitySource("eShop.Orders.Startup")
        .StartActivity("Application.ConfigureMiddleware", ActivityKind.Internal))
    {
        middlewareActivity?.SetTag("configuration.step", "openapi");
        app.MapOpenApi();
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/openapi/v1.json", "eShop.Orders.API v1");
    options.RoutePrefix = string.Empty; // Serve Swagger UI at application root (http://localhost:port/)
});


// Map health check endpoints FIRST for container orchestration probes
// Health checks must respond on HTTP without HTTPS redirect
// Used by load balancers and container orchestrators (Kubernetes, Container Apps)
app.MapDefaultEndpoints();

// Add correlation ID middleware early in pipeline
// Ensures all subsequent middleware and logging operations have access to correlation ID
app.UseCorrelationId();

// Redirect HTTP requests to HTTPS for security (but after health checks)
// In container environments, ingress handles HTTPS termination
if (!app.Environment.IsProduction())
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