// ------------------------------------------------------------------------------
// <copyright file="Program.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Application entry point for the Orders Web App (Blazor Server).
//     Configures Razor Components with WebAssembly interactivity.
// </summary>
// ------------------------------------------------------------------------------

using eShop.Orders.App.Components;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults: OpenTelemetry, health checks, and service discovery
builder.AddServiceDefaults();

// Configure Blazor Server with WebAssembly interactive rendering mode
// Enables hybrid rendering: Server-side on initial load, client-side for interactivity
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyComponents();

var app = builder.Build();

// Map health check endpoints for monitoring
app.MapDefaultEndpoints();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    // Enable WebAssembly debugging in development
    // Allows debugging Blazor WebAssembly code directly in the browser
    app.UseWebAssemblyDebugging();
}
else
{
    // Production error handling: redirect to error page
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    
    // HTTP Strict Transport Security (HSTS) for production
    // Enforces HTTPS for 30 days (consider extending for production)
    app.UseHsts();
}

// Redirect all HTTP requests to HTTPS
app.UseHttpsRedirection();

// Enable anti-forgery token validation for forms
app.UseAntiforgery();

// Map static assets (CSS, JS, images) with optimized caching
app.MapStaticAssets();

// Map Razor Components with WebAssembly interactivity
// Includes client-side assembly for interactive components
app.MapRazorComponents<App>()
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(eShop.Orders.App.Client._Imports).Assembly);

app.Run();
