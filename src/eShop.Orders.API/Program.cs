using eShop.Orders.API.Handlers;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Repositories;
using eShop.Orders.API.Services;
using eShop.Orders.API.Services.Interfaces;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Add services to the container.
builder.Services.Configure<OrderStorageOptions>(
    builder.Configuration.GetSection(OrderStorageOptions.SectionName));

builder.Services.AddScoped<IOrderRepository, OrderRepository>();
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<IOrdersMessageHandler, OrdersMessageHandler>();

builder.Services.AddControllers();

// Configure OpenAPI/Swagger
builder.Services.AddOpenApi();
builder.Services.AddSwaggerGen();
builder.Services.AddEndpointsApiExplorer();

// Add Azure Service Bus client
builder.AddAzureServiceBusClient();

var app = builder.Build();

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