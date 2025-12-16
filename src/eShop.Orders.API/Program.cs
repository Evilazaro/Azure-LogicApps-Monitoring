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

// Register Azure Service Bus client using Aspire integration
// Provides automatic health checks, telemetry, and configuration management
// Connection name "messaging" maps to the Service Bus resource defined in AppHost
builder.AddAzureServiceBusClient("messaging");

// Register background service for continuous message processing from Service Bus
builder.Services.AddHostedService<OrderMessageHandler>();

var app = builder.Build();

// Configure the HTTP request pipeline
// Middleware order is critical - each component processes requests in order
if (app.Environment.IsDevelopment())
{
    // Enable OpenAPI/Swagger UI only in development for security
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

// Redirect HTTP requests to HTTPS for security
app.UseHttpsRedirection();

// Enable authorization middleware (currently configured but not enforcing policies)
app.UseAuthorization();

// Map API controllers to handle HTTP requests
app.MapControllers();

// Map health check endpoints for monitoring and orchestration
// Used by load balancers and container orchestrators (Kubernetes, Container Apps)
app.MapDefaultEndpoints();

app.Run();