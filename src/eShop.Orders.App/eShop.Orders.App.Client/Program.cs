using eShop.Orders.App.Client.Extensions;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Add diagnostic logging
builder.Logging.SetMinimumLevel(LogLevel.Debug);

var ordersApiBaseAddress = builder.Configuration["OrdersApi:BaseAddress"] 
    ?? builder.Configuration.GetConnectionString("orders-api")
    ?? builder.HostEnvironment.BaseAddress;

// Log the resolved address
Console.WriteLine($"Orders API Base Address: {ordersApiBaseAddress}");

builder.Services.AddOrderServices(ordersApiBaseAddress, builder.HostEnvironment.IsDevelopment());

await builder.Build().RunAsync();