// ------------------------------------------------------------------------------
// <copyright file="Program.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Application entry point for the Orders Web App.
//     Configures services, middleware, and components for Blazor Server rendering.
// </summary>
// ------------------------------------------------------------------------------

using eShop.Orders.App.Components;
using System.Diagnostics;

// Static ActivitySource for application startup tracing
// Persists for the application lifetime to ensure proper trace correlation
var startupActivitySource = new ActivitySource("eShop.Orders.App.Startup");

// Create activity for application startup tracing
using var startupActivity = startupActivitySource.StartActivity("Application.Startup", ActivityKind.Internal);

startupActivity?.SetTag("service.name", "eShop.Orders.App");
startupActivity?.SetTag("deployment.environment", Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown");

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// Add service defaults: OpenTelemetry instrumentation, health checks, service discovery, and resilience
using (var configActivity = startupActivitySource.StartActivity("Application.ConfigureServices", ActivityKind.Internal))
{
    configActivity?.SetTag("configuration.step", "service_defaults");
    builder.AddServiceDefaults();

    // Add Blazor components with interactive server-side rendering
    configActivity?.SetTag("configuration.step", "razor_components");
    builder.Services.AddRazorComponents()
        .AddInteractiveServerComponents();

    // Configure HTTP client for Orders API with service discovery
    // The base address is automatically resolved from Aspire service discovery
    configActivity?.SetTag("configuration.step", "http_client");
    builder.Services.AddHttpClient("eShop.Orders.API", client =>
    {
        // Service discovery resolves "services:orders-api:https:0" to actual endpoint
        var baseAddress = builder.Configuration["services:orders-api:https:0"];
        if (string.IsNullOrWhiteSpace(baseAddress))
        {
            throw new InvalidOperationException(
                "Orders API service endpoint not found. Ensure the API service is referenced in AppHost.");
        }

        client.BaseAddress = new Uri(baseAddress);
        client.DefaultRequestHeaders.Add("Accept", "application/json");
        client.Timeout = TimeSpan.FromSeconds(30);
    });

    configActivity?.AddEvent(new ActivityEvent("Services configured successfully"));
}


using (var buildActivity = startupActivitySource.StartActivity("Application.Build", ActivityKind.Internal))
{
    var app = builder.Build();
    buildActivity?.AddEvent(new ActivityEvent("Application built successfully"));

    using (var middlewareActivity = startupActivitySource.StartActivity("Application.ConfigureMiddleware", ActivityKind.Internal))
    {
        // Map health check endpoints FIRST for container orchestration probes
        app.MapDefaultEndpoints();

        // Configure error handling based on environment
        if (!app.Environment.IsDevelopment())
        {
            // Use exception handler page in production
            app.UseExceptionHandler("/Error", createScopeForErrors: true);

            // Enable HSTS (HTTP Strict Transport Security)
            // The default HSTS value is 30 days. Consider extending for production.
            // See: https://aka.ms/aspnetcore-hsts
            app.UseHsts();
        }

        // HTTPS redirection is handled differently based on environment
        // In development: Redirect to HTTPS for local testing
        // In production/container environments: Ingress/load balancer handles HTTPS termination
        if (app.Environment.IsDevelopment())
        {
            app.UseHttpsRedirection();
        }

        // Enable antiforgery protection for form submissions
        app.UseAntiforgery();

        // Map static assets (wwwroot files)
        middlewareActivity?.SetTag("configuration.step", "static_assets");
        app.MapStaticAssets();

        // Map Razor components with interactive server-side rendering
        middlewareActivity?.SetTag("configuration.step", "razor_components");
        app.MapRazorComponents<App>()
            .AddInteractiveServerRenderMode();

        middlewareActivity?.AddEvent(new ActivityEvent("Middleware configured successfully"));
    }

    startupActivity?.SetStatus(ActivityStatusCode.Ok);
    startupActivity?.AddEvent(new ActivityEvent("Application startup completed"));

    app.Run();
}
