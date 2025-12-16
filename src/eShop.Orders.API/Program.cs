using eShop.Orders.API.Services;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Add API services
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        // Customize validation error responses
        options.InvalidModelStateResponseFactory = context =>
        {
            var logger = context.HttpContext.RequestServices
                .GetRequiredService<ILogger<Program>>();

            logger.LogWarning(
                "Model validation failed for {Path}. Errors: {Errors}",
                context.HttpContext.Request.Path,
                string.Join(", ", context.ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)));

            return new BadRequestObjectResult(new ValidationProblemDetails(context.ModelState)
            {
                Title = "One or more validation errors occurred.",
                Status = StatusCodes.Status400BadRequest,
                Instance = context.HttpContext.Request.Path
            });
        };
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new()
    {
        Title = "eShop Orders API",
        Version = "v1",
        Description = "API for managing orders in the eShop system with Azure Service Bus integration"
    });

    // Include XML comments for better API documentation
    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
    {
        options.IncludeXmlComments(xmlPath);
    }
});

// Register Azure Service Bus client with proper configuration
builder.AddAzureServiceBusClient("messaging");

// Register application services with dependency injection
builder.Services.AddSingleton<IOrderService, OrderService>();

// Add health checks for Service Bus and application health
builder.Services.AddHealthChecks()
    .AddAzureServiceBusQueue(
        sp => sp.GetRequiredService<IConfiguration>().GetConnectionString("messaging") ?? throw new InvalidOperationException("Service Bus connection string 'messaging' not found"),
        sp => sp.GetRequiredService<IConfiguration>()["ServiceBus:QueueName"] ?? "orders",
        name: "servicebus-orders-queue");

var app = builder.Build();

app.MapDefaultEndpoints();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "eShop Orders API v1");
        options.RoutePrefix = string.Empty;
        options.DocumentTitle = "eShop Orders API";
        options.DisplayRequestDuration();
    });
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();