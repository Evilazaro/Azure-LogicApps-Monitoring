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
using System.Diagnostics;

// Create activity source for application startup tracing
using var startupActivity = new ActivitySource("eShop.Orders.App.Startup")
    .StartActivity("WebApp.Startup", ActivityKind.Internal);

startupActivity?.SetTag("service.name", "eShop.Orders.App");
startupActivity?.SetTag("app.type", "blazor-server");

var builder = WebApplication.CreateBuilder(args);

using (var configActivity = new ActivitySource("eShop.Orders.App.Startup")
    .StartActivity("WebApp.ConfigureServices", ActivityKind.Internal))
{
    configActivity?.SetTag("configuration.step", "service_defaults");
    builder.AddServiceDefaults();

    // Add services to the container.
    configActivity?.SetTag("configuration.step", "razor_components");
    builder.Services.AddRazorComponents()
        .AddInteractiveWebAssemblyComponents();

    // Configure HTTP client for Orders API with service discovery
    // The configuration key is automatically provided by Aspire based on the service reference
    configActivity?.SetTag("configuration.step", "http_clients");
    builder.Services.AddHttpClient("orders-api", client =>
    {
        var baseUrl = builder.Configuration["services:orders-api:https:0"]
                      ?? builder.Configuration["services:orders-api:http:0"]
                      ?? throw new InvalidOperationException("Orders API service URL not found in configuration");

        client.BaseAddress = new Uri(baseUrl);
        client.DefaultRequestHeaders.Add("Accept", "application/json");
        client.Timeout = TimeSpan.FromSeconds(30);
    });

    configActivity?.AddEvent(new ActivityEvent("Services configured successfully"));
}

using (var buildActivity = new ActivitySource("eShop.Orders.App.Startup")
    .StartActivity("WebApp.Build", ActivityKind.Internal))
{
    var app = builder.Build();
    buildActivity?.AddEvent(new ActivityEvent("Application built successfully"));

    using (var middlewareActivity = new ActivitySource("eShop.Orders.App.Startup")
        .StartActivity("WebApp.ConfigureMiddleware", ActivityKind.Internal))
    {
        app.MapDefaultEndpoints();

        // Configure the HTTP request pipeline based on environment
        middlewareActivity?.SetTag("configuration.step", "error_handling");
        if (app.Environment.IsDevelopment())
        {
            app.UseWebAssemblyDebugging();
        }
        else
        {
            app.UseExceptionHandler("/Error", createScopeForErrors: true);
            // The default HSTS value is 30 days. You may want to change this for production scenarios
            app.UseHsts();
        }

        // HTTPS redirection - load balancer handles this in production
        middlewareActivity?.SetTag("configuration.step", "https_redirect");
        app.UseHttpsRedirection();

        // Anti-forgery protection for form submissions
        middlewareActivity?.SetTag("configuration.step", "antiforgery");
        app.UseAntiforgery();

        app.MapStaticAssets();
        app.MapRazorComponents<App>()
            .AddInteractiveWebAssemblyRenderMode()
            .AddAdditionalAssemblies(typeof(eShop.Orders.App.Client._Imports).Assembly);

        middlewareActivity?.AddEvent(new ActivityEvent("Middleware configured successfully"));
    }

    startupActivity?.SetStatus(ActivityStatusCode.Ok);
    startupActivity?.AddEvent(new ActivityEvent("Web app startup completed"));

    app.Run();
}
