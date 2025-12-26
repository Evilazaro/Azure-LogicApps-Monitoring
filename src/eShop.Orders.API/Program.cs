using eShop.Orders.API.Data;
using eShop.Orders.API.Handlers;
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
    var connectionString = builder.Configuration.GetConnectionString("OrderDb");

    if (string.IsNullOrWhiteSpace(connectionString))
    {
        throw new InvalidOperationException(
            "Connection string 'OrderDb' is not configured. " +
            "Please ensure the connection string is properly set in appsettings.json or environment variables.");
    }

    options.UseSqlServer(connectionString, sqlOptions =>
    {
        // Configure retry strategy for transient failures
        sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(30),
            errorNumbersToAdd: null);

        // Set command timeout
        sqlOptions.CommandTimeout(30);
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
builder.Services.AddScoped<IOrdersMessageHandler, OrdersMessageHandler>();

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


// Add Azure Service Bus client configuration
builder.AddAzureServiceBusClient();

var app = builder.Build();


using var scope = app.Services.CreateScope();
var dbContext = scope.ServiceProvider.GetRequiredService<OrderDbContext>();

try
{
    dbContext.Database.EnsureCreated();
    //await dbContext.Database.MigrateAsync();
}
catch (Exception ex)
{
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    logger.LogError(ex, "An error occurred while migrating the database.");
}

app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "v1");
        options.RoutePrefix = string.Empty;
    });
    app.MapSwagger();
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/error");
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();