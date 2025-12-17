using eShop.Orders.App.Client.Extensions;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Configure logging
builder.Logging.SetMinimumLevel(LogLevel.Information);

// Get Orders API base address from configuration
var ordersApiBaseAddress = builder.Configuration["OrdersApi:BaseAddress"] 
    ?? builder.HostEnvironment.BaseAddress;

// Determine if running in development mode
var isDevelopment = builder.HostEnvironment.IsDevelopment();

// Register order services with OpenTelemetry instrumentation
builder.Services.AddOrderServices(ordersApiBaseAddress, isDevelopment);

await builder.Build().RunAsync();