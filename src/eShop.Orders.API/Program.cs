using eShop.Orders.API.Middleware;
using eShop.Orders.API.Services;
using Microsoft.AspNetCore.Mvc.ApplicationParts;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (includes OpenTelemetry configuration)
builder.AddServiceDefaults();

// Add controllers
builder.Services.AddControllers();

// Add Swagger for API documentation
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen();

// Register HTTP clients with automatic tracing
builder.Services.AddHttpClient<ExternalApiClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ExternalApi:BaseUrl"] ?? "https://api.external.com");
    client.DefaultRequestHeaders.Add("Accept", "application/json");
});

// Register Service Bus message handler
builder.Services.AddSingleton(sp =>
{
    var connectionString = builder.Configuration["ServiceBus:ConnectionString"];
    return new Azure.Messaging.ServiceBus.ServiceBusClient(connectionString);
});
builder.Services.AddHostedService<OrderMessageHandler>();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "eShop.Orders.API v1");
        options.RoutePrefix = string.Empty; // Serve Swagger UI at application root
    });
}

// Add correlation ID middleware (must be early in pipeline)
app.UseCorrelationId();

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

// Map default health check endpoints
app.MapDefaultEndpoints();

app.Run();