using eShop.Orders.App.Client.Extensions;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Configure logging
builder.Logging.SetMinimumLevel(LogLevel.Information);

// For Aspire deployments, the WebAssembly client calls the server's proxy endpoints
// instead of calling the Orders API directly. This allows the server to use
// Aspire service discovery to locate the Orders API.
//
// Priority 1: OrdersApi:BaseAddress from configuration (should be "/" for proxy)
// Priority 2: Host environment base address (fallback)
var ordersApiBaseAddress = builder.Configuration["OrdersApi:BaseAddress"]
    ?? builder.HostEnvironment.BaseAddress;

// Log configuration for diagnostics
if (builder.HostEnvironment.IsDevelopment())
{
    Console.WriteLine($"[OrdersApp.Client] Orders API Base Address: {ordersApiBaseAddress}");
    Console.WriteLine($"[OrdersApp.Client] Host Environment: {builder.HostEnvironment.Environment}");
}

// Register order services with OpenTelemetry instrumentation
// The OrderService will use the configured base address to call the server's proxy endpoints
builder.Services.AddOrderServices(ordersApiBaseAddress, builder.HostEnvironment.IsDevelopment());

await builder.Build().RunAsync();