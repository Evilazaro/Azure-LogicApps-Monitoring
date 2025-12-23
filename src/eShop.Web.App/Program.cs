using eShop.Web.App.Components;
using eShop.Web.App.Components.Services;
using Microsoft.FluentUI.AspNetCore.Components;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Add SignalR services for Blazor Server
builder.Services.AddSignalR(options =>
{
    if (builder.Environment.IsDevelopment())
    {
        options.EnableDetailedErrors = true;
    }
});

// Configure circuit options for better reliability and debugging
builder.Services.Configure<Microsoft.AspNetCore.Components.Server.CircuitOptions>(options =>
{
    if (builder.Environment.IsDevelopment())
    {
        options.DetailedErrors = true;
    }
    options.DisconnectedCircuitMaxRetained = 100;
    options.DisconnectedCircuitRetentionPeriod = TimeSpan.FromMinutes(3);
    options.JSInteropDefaultCallTimeout = TimeSpan.FromMinutes(1);
    options.MaxBufferedUnacknowledgedRenderBatches = 10;
});

// Configure HTTP client for Orders API with proper error handling
builder.Services.AddHttpClient<OrdersAPIService>(client =>
{
    var baseAddress = builder.Configuration["services:orders-api:https:0"] 
                    ?? builder.Configuration["services:orders-api:http:0"]
                    ?? throw new InvalidOperationException("Orders API base address not configured");
    
    client.BaseAddress = new Uri(baseAddress);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
    client.Timeout = TimeSpan.FromSeconds(30);
});

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
