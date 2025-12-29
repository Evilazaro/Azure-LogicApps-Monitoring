using eShop.Orders.API.Data;
using eShop.Orders.API.Handlers;
using eShop.Orders.API.HealthChecks;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Repositories;
using eShop.Orders.API.Services;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;
using System.Diagnostics.Metrics;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Register observability components for dependency injection
builder.Services.AddSingleton(new ActivitySource("eShop.Orders.API"));
builder.Services.AddSingleton(new Meter("eShop.Orders.API"));

// Configure Entity Framework Core with SQL Server
builder.Services.AddDbContext<OrderDbContext>(options =>
{
    var connectionString = builder.Configuration["ConnectionStrings:OrdersDatabase"];

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        // During manifest generation, we need to provide a minimal valid configuration
        // This allows the manifest to be generated without throwing exceptions
        // At runtime, the actual connection string will be provided by Aspire
        Console.WriteLine("Warning: Connection string 'OrdersDatabase' is not configured yet. Using placeholder configuration.");
        options.UseSqlServer("Server=.;Database=placeholder;Integrated Security=true;TrustServerCertificate=true;");
        return;
    }

    // Use standard UseSqlServer - Aspire automatically configures Azure AD authentication
    // via the connection string when using WithReference() in AppHost
    options.UseSqlServer(connectionString, sqlOptions =>
    {
        // Enable connection resiliency for Azure SQL
        sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(30),
            errorNumbersToAdd: null);

        // Set command timeout for long-running operations
        sqlOptions.CommandTimeout(120);
    });

    // Enable sensitive data logging in development only
    if (builder.Environment.IsDevelopment())
    {
        options.EnableSensitiveDataLogging();
        options.EnableDetailedErrors();
    }
});

// Register application services with scoped lifetime
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<IOrderService, OrderService>();

builder.Services.AddControllers();

// Configure OpenAPI/Swagger for API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
    {
        Title = "eShop Orders API",
        Version = "v1",
        Description = "API for managing customer orders in the eShop application"
    });

    // Include XML comments in Swagger documentation
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        options.IncludeXmlComments(xmlPath);
    }
});

// Add Azure Service Bus client configuration - only if configured
var serviceBusHostName = builder.Configuration["Azure:ServiceBus:HostName"]
                         ?? builder.Configuration["MESSAGING_HOST"];

if (!string.IsNullOrWhiteSpace(serviceBusHostName))
{
    builder.AddAzureServiceBusClient();
    builder.Services.AddScoped<IOrdersMessageHandler, OrdersMessageHandler>();
}
else
{
    // Register a no-op message handler for development without Service Bus
    builder.Services.AddScoped<IOrdersMessageHandler, NoOpOrdersMessageHandler>();
}

// Configure health checks
var healthChecksBuilder = builder.Services.AddHealthChecks();

// Add database health check
healthChecksBuilder.AddCheck<DbContextHealthCheck>("database", tags: new[] { "ready", "db" });

// Only add Service Bus health check if it's configured
if (!string.IsNullOrWhiteSpace(serviceBusHostName))
{
    healthChecksBuilder.AddCheck<ServiceBusHealthCheck>("servicebus", tags: new[] { "ready", "servicebus" });
}

var app = builder.Build();

// Log warning about missing Service Bus configuration (if applicable)
if (string.IsNullOrWhiteSpace(serviceBusHostName))
{
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogWarning("Service Bus is not configured. Orders will not be published to the message queue.");
}

// Initialize database asynchronously in the background
// This allows the application to start and respond to health probes
// even if the database is not immediately available (e.g., during initial deployment)
_ = Task.Run(async () =>
{
    using var scope = app.Services.CreateScope();
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();

    var maxRetries = 10;
    var retryDelay = TimeSpan.FromSeconds(5);

    for (int attempt = 1; attempt <= maxRetries; attempt++)
    {
        try
        {
            var dbContext = services.GetRequiredService<OrderDbContext>();
            var connectionString = builder.Configuration.GetConnectionString("OrdersDatabase");

            logger.LogInformation("Initializing database (attempt {Attempt}/{MaxRetries})...", attempt, maxRetries);
            logger.LogInformation("Database server: {Server}",
                connectionString?.Contains("Server=", StringComparison.OrdinalIgnoreCase) == true
                    ? connectionString.Split("Server=", StringSplitOptions.None)[1].Split(';')[0]
                    : "Not specified");

            logger.LogInformation("Ensuring database is created (development mode)...");
            await dbContext.Database.EnsureCreatedAsync();
            logger.LogInformation("Database ensured created for development environment");

            // Test database connectivity
            var canConnect = await dbContext.Database.CanConnectAsync();
            if (canConnect)
            {
                logger.LogInformation("Database connection test successful");
                return; // Success - exit retry loop
            }
            else
            {
                logger.LogWarning("Database connection test failed");
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Database initialization failed (attempt {Attempt}/{MaxRetries}). " +
                "Error: {ErrorMessage}. " +
                "Connection string configured: {HasConnectionString}. " +
                "Will retry in {RetryDelay} seconds...",
                attempt,
                maxRetries,
                ex.Message,
                !string.IsNullOrWhiteSpace(builder.Configuration.GetConnectionString("OrdersDatabase")),
                retryDelay.TotalSeconds);

            // Log additional diagnostic information on first failure
            if (attempt == 1)
            {
                logger.LogError("Environment: {Environment}", app.Environment.EnvironmentName);
                logger.LogError("Configuration sources: {Sources}",
                    string.Join(", ", builder.Configuration.AsEnumerable()
                        .Where(kvp => kvp.Key.Contains("ConnectionStrings", StringComparison.OrdinalIgnoreCase))
                        .Select(kvp => $"{kvp.Key}={(kvp.Value?.Length > 0 ? "***" : "empty")}")));
            }

            if (attempt < maxRetries)
            {
                await Task.Delay(retryDelay);
            }
            else
            {
                logger.LogCritical("Database initialization failed after {MaxRetries} attempts. " +
                    "The application will continue to run, but database operations will fail. " +
                    "Please check: 1) SQL Server is accessible, 2) Managed identity has proper permissions, " +
                    "3) Firewall rules allow Container App access.",
                    maxRetries);
            }
        }
    }
});

app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "eShop Orders API v1");
        options.RoutePrefix = string.Empty;
        options.DocumentTitle = "eShop Orders API";
    });
    app.MapSwagger();
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/error");
    app.UseHsts();
}

// Add security headers for production
if (!app.Environment.IsDevelopment())
{
    app.Use(async (context, next) =>
    {
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["X-Frame-Options"] = "DENY";
        context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        await next();
    });
}

// Global error handler endpoint
app.MapGet("/error", () => Results.Problem("An error occurred processing your request."))
    .ExcludeFromDescription();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();