// =============================================================================
// eShop Web App - Entry Point
// Blazor Server application for eShop order management UI
// =============================================================================

using eShop.Web.App.Components;
using eShop.Web.App.Components.Services;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Configure distributed memory cache for session state
// In production with multiple instances, consider using Redis or SQL Server
builder.Services.AddDistributedMemoryCache();

// Configure session management
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(30);
    options.Cookie.Name = ".eShop.Session";
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
    options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
    options.Cookie.SameSite = SameSiteMode.Strict;
});

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

// Configure typed HTTP client for Orders API with service discovery
// Note: Resilience policies (retry, timeout, circuit breaker) are already configured
// globally by AddServiceDefaults() with appropriate timeouts for batch operations
builder.Services.AddHttpClient<OrdersAPIService>(client =>
{
    var baseAddress = builder.Configuration["services:orders-api:https:0"];

    if (string.IsNullOrWhiteSpace(baseAddress))
    {
        throw new InvalidOperationException(
            "Orders API base address not configured. " +
            "Ensure 'services:orders-api:https:0' is properly set in configuration or service discovery is enabled.");
    }

    client.BaseAddress = new Uri(baseAddress);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
    client.DefaultRequestHeaders.Add("User-Agent", "eShop.Web.App");
    client.Timeout = TimeSpan.FromMinutes(10); // Allow enough time for batch operations
})
.AddServiceDiscovery(); // Service discovery for endpoint resolution

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

app.UseSession();

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
