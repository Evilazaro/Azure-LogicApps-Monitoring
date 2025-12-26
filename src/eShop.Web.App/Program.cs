using eShop.Web.App.Components;
using eShop.Web.App.Components.Services;
using Microsoft.FluentUI.AspNetCore.Components;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Register observability components for dependency injection
builder.Services.AddSingleton(new ActivitySource("eShop.Web.App"));

// Add Razor Components with interactive server-side rendering
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Configure SignalR for Blazor Server with optimal settings
builder.Services.AddSignalR(options =>
{
    if (builder.Environment.IsDevelopment())
    {
        options.EnableDetailedErrors = true;
    }
    options.MaximumReceiveMessageSize = 32 * 1024; // 32 KB
    options.StreamBufferCapacity = 10;
    options.HandshakeTimeout = TimeSpan.FromMinutes(2);
    options.KeepAliveInterval = TimeSpan.FromSeconds(15);
    options.ClientTimeoutInterval = TimeSpan.FromMinutes(5);
});

// Configure circuit options for better reliability and debugging
builder.Services.Configure<Microsoft.AspNetCore.Components.Server.CircuitOptions>(options =>
{
    if (builder.Environment.IsDevelopment())
    {
        options.DetailedErrors = true;
    }
    options.DisconnectedCircuitMaxRetained = 100;
    options.DisconnectedCircuitRetentionPeriod = TimeSpan.FromMinutes(10);
    options.JSInteropDefaultCallTimeout = TimeSpan.FromMinutes(10);
    options.MaxBufferedUnacknowledgedRenderBatches = 10;
});

// Configure typed HTTP client for Orders API with resilience and service discovery
builder.Services.AddHttpClient<OrdersAPIService>((serviceProvider, client) =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    var baseAddress = configuration["services:orders-api:https:0"];
    
    if (string.IsNullOrWhiteSpace(baseAddress))
    {
        throw new InvalidOperationException(
            "Orders API base address not configured. " +
            "Ensure 'services:orders-api:https:0' is properly set in configuration or service discovery is enabled.");
    }

    client.BaseAddress = new Uri(baseAddress);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
    client.DefaultRequestHeaders.Add("User-Agent", "eShop.Web.App");
    client.Timeout = TimeSpan.FromMinutes(5);
})
.AddServiceDiscovery() // Enables service discovery - must be called before AddStandardResilienceHandler
.AddStandardResilienceHandler(); // Add retry, timeout, and circuit breaker policies

builder.Services.AddFluentUIComponents();

var app = builder.Build();

app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
