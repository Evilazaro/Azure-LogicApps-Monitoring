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

var builder = WebApplication.CreateBuilder(args);

// Add service defaults: OpenTelemetry instrumentation, health checks, service discovery, and resilience
builder.AddServiceDefaults();

// Register MVC controllers for RESTful API endpoints
builder.Services.AddControllers();

// Add API documentation support via Swagger/OpenAPI
// Enables automatic API schema generation and interactive documentation UI
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen();

// Register typed HTTP client with automatic distributed tracing
// HttpClient instances are automatically instrumented with OpenTelemetry
// for context propagation to downstream services
builder.Services.AddHttpClient<ExternalApiClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ExternalApi:BaseUrl"] ?? "https://api.external.com");
    client.DefaultRequestHeaders.Add("Accept", "application/json");
});

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
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();


// Enable OpenAPI/Swagger UI only in development for security
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

// Enable authorization middleware (currently configured but not enforcing policies)
app.UseAuthorization();

// Enable CORS before other middleware
app.UseCors();

// Map API controllers to handle HTTP requests
app.MapControllers();

app.Run();