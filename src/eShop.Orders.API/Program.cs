// =============================================================================
// eShop Orders API - Entry Point
// ASP.NET Core Web API for order management with Azure integration
// =============================================================================

using eShop.Orders.API.Data;
using eShop.Orders.API.Handlers;
using eShop.Orders.API.HealthChecks;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Repositories;
using eShop.Orders.API.Services;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Register observability components for dependency injection
builder.Services.AddSingleton(new ActivitySource("eShop.Orders.API"));

var connectionString = builder.Configuration.GetConnectionString("OrderDb");

// =============================================================================
// Entity Framework Core Configuration
// Best Practice: Configure EF Core with resilience patterns for Azure SQL
// =============================================================================
builder.Services.AddDbContext<OrderDbContext>(options =>
{
    if (string.IsNullOrWhiteSpace(connectionString))
    {
        throw new InvalidOperationException(
            "Connection string 'OrderDb' is not configured. Ensure the database resource is referenced so the connection string is provided.");
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
    options.SwaggerDoc("v1", new()
    {
        Title = "eShop Orders API",
        Version = "v1",
        Description = "API for managing orders in the eShop application."
    });
});

// Add Azure Service Bus client configuration - only if configured
var serviceBusHostName = builder.Configuration["Azure:ServiceBus:HostName"]
                         ?? builder.Configuration["MESSAGING_HOST"];

var serviceBusConnectionString = builder.Configuration.GetConnectionString("messaging");
var isServiceBusEnabled = !string.IsNullOrWhiteSpace(serviceBusHostName)
    && (!serviceBusHostName.Equals("localhost", StringComparison.OrdinalIgnoreCase)
        || !string.IsNullOrWhiteSpace(serviceBusConnectionString));

if (isServiceBusEnabled)
{
    builder.AddAzureServiceBusClient();
    builder.Services.AddSingleton<IOrdersMessageHandler, OrdersMessageHandler>();
}
else
{
    // Register a no-op message handler for development without Service Bus
    builder.Services.AddSingleton<IOrdersMessageHandler, NoOpOrdersMessageHandler>();
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
if (!isServiceBusEnabled)
{
    var logger = app.Services.GetRequiredService<ILogger<Program>>();
    logger.LogWarning("Service Bus is not configured. Orders will not be published to the message queue.");
}

app.Lifetime.ApplicationStarted.Register(() =>
{
    _ = InitializeDatabaseAsync(app.Services, app.Lifetime.ApplicationStopping, app.Logger);
});

static async Task InitializeDatabaseAsync(IServiceProvider serviceProvider, CancellationToken cancellationToken, ILogger logger)
{
    var maxRetries = 10;
    var retryDelay = TimeSpan.FromSeconds(5);

    for (var attempt = 1; attempt <= maxRetries && !cancellationToken.IsCancellationRequested; attempt++)
    {
        try
        {
            using var scope = serviceProvider.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<OrderDbContext>();

            logger.LogInformation("Initializing database (attempt {Attempt}/{MaxRetries})...", attempt, maxRetries);

            await dbContext.Database.MigrateAsync(cancellationToken);

            if (await dbContext.Database.CanConnectAsync(cancellationToken))
            {
                logger.LogInformation("Database connection test successful");
                return;
            }

            logger.LogWarning("Database connection test failed");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return;
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Database initialization failed (attempt {Attempt}/{MaxRetries}). Will retry in {RetryDelaySeconds} seconds...",
                attempt,
                maxRetries,
                retryDelay.TotalSeconds);

            if (attempt < maxRetries)
            {
                try
                {
                    await Task.Delay(retryDelay, cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    return;
                }
            }
            else
            {
                logger.LogCritical(ex, "Database initialization failed after {MaxRetries} attempts", maxRetries);
            }
        }
    }
}

app.MapDefaultEndpoints();

app.MapOpenApi();
app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/openapi/v1.json", "eShop Orders API v1");
    options.RoutePrefix = string.Empty;
    options.DocumentTitle = "eShop Orders API";
});
app.MapSwagger();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
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