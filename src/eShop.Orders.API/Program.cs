using eShop.Orders.API.Data;
using eShop.Orders.API.Handlers;
using eShop.Orders.API.HealthChecks;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Repositories;
using eShop.Orders.API.Services;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
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
    var connectionString = builder.Configuration.GetConnectionString("OrderDb");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        throw new InvalidOperationException(
            "Connection string 'OrderDb' is not configured. " +
            "Please ensure the connection string is properly set in appsettings.json or environment variables.");
    }

    options.UseAzureSql(connectionString);

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
builder.Services.AddOpenApi();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
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

// Add self health check
healthChecksBuilder.AddCheck("self", () => HealthCheckResult.Healthy("Application is running"), tags: new[] { "live" });

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

// Initialize database with proper async handling
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();

    try
    {
        var dbContext = services.GetRequiredService<OrderDbContext>();
        logger.LogInformation("Initializing database...");

        // Use migrations in production, EnsureCreated for development
        if (app.Environment.IsProduction())
        {
            await dbContext.Database.MigrateAsync();
            logger.LogInformation("Database migration completed successfully");
        }
        else
        {
            await dbContext.Database.EnsureCreatedAsync();
            logger.LogInformation("Database ensured created for development environment");
        }
    }
    catch (Exception ex)
    {
        logger.LogCritical(ex, "A fatal error occurred while initializing the database. Application cannot start.");
        throw; // Re-throw to prevent application from starting with invalid database state
    }
}

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
    app.UseHsts(); // Add HSTS for production
}

// Global error handler endpoint
app.MapGet("/error", () => Results.Problem("An error occurred processing your request."))
    .ExcludeFromDescription();

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();