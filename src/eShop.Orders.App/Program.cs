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
using eShop.Orders.App.Client.Models;
using Microsoft.AspNetCore.Mvc;
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

    // Configure typed HttpClient for Orders API with Aspire service discovery and resilience
    // This is used by the server-side proxy to communicate with the Orders API
    configActivity?.SetTag("configuration.step", "orders_api_client");
    builder.Services.AddHttpClient("orders-api", (serviceProvider, client) =>
    {
        var configuration = serviceProvider.GetRequiredService<IConfiguration>();
        
        // Use Aspire service discovery to resolve the Orders API endpoint
        var baseUrl = configuration["services:orders-api:https:0"] 
                      ?? configuration["services:orders-api:http:0"]
                      ?? throw new InvalidOperationException("Orders API service URL not found in configuration");
        
        client.BaseAddress = new Uri(baseUrl);
        client.DefaultRequestHeaders.Add("Accept", "application/json");
        client.Timeout = TimeSpan.FromSeconds(30);
    })
    .AddServiceDiscovery()          // Add Aspire service discovery
    .AddStandardResilienceHandler(); // Add resilience patterns (retry, circuit breaker, timeout)

    // Configure CORS for WebAssembly client (if needed for cross-origin scenarios)
    configActivity?.SetTag("configuration.step", "cors");
    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            if (builder.Environment.IsDevelopment())
            {
                // Allow all origins in development
                policy.AllowAnyOrigin()
                      .AllowAnyMethod()
                      .AllowAnyHeader();
            }
            else
            {
                // In production, restrict to configured origins
                var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
                if (allowedOrigins.Length > 0)
                {
                    policy.WithOrigins(allowedOrigins)
                          .AllowAnyMethod()
                          .AllowAnyHeader()
                          .AllowCredentials();
                }
            }
        });
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
        // Map health check endpoints FIRST for container orchestration probes
        app.MapDefaultEndpoints();

        // Configure the HTTP request pipeline.
        if (app.Environment.IsDevelopment())
        {
            app.UseWebAssemblyDebugging();
        }
        else
        {
            // Enhanced exception handling with structured logging
            app.UseExceptionHandler(exceptionHandlerApp =>
            {
                exceptionHandlerApp.Run(async context =>
                {
                    var exceptionHandlerFeature = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>();
                    var exception = exceptionHandlerFeature?.Error;
                    
                    // Log exception with OpenTelemetry
                    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
                    logger.LogError(exception, "Unhandled exception occurred in Blazor Web App");
                    
                    context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                    context.Response.Redirect("/Error");
                });
            });
            
            app.UseHsts();
        }

        app.UseHttpsRedirection();

        // Enable CORS before anti-forgery
        app.UseCors();

        // Configure anti-forgery for WebAssembly scenarios
        app.UseAntiforgery();

        app.MapStaticAssets();

        // Map server-side proxy endpoints for WebAssembly client
        // This allows the client to call the server, which then calls the Orders API
        // This is the recommended pattern for Aspire as it keeps service discovery internal
        middlewareActivity?.SetTag("configuration.step", "proxy_endpoints");
        MapProxyEndpoints(app);

        app.MapRazorComponents<App>()
            .AddInteractiveWebAssemblyRenderMode()
            .AddAdditionalAssemblies(typeof(eShop.Orders.App.Client._Imports).Assembly);

        middlewareActivity?.AddEvent(new ActivityEvent("Middleware configured successfully"));
    }

    startupActivity?.SetStatus(ActivityStatusCode.Ok);
    startupActivity?.AddEvent(new ActivityEvent("Web app startup completed"));

    app.Run();
}

/// <summary>
/// Maps proxy endpoints for the WebAssembly client to communicate with the Orders API.
/// The WebAssembly client calls these proxy endpoints on the server, which then forwards
/// requests to the Orders API using Aspire service discovery.
/// </summary>
static void MapProxyEndpoints(WebApplication app)
{
    var proxyGroup = app.MapGroup("/api/proxy")
        .WithTags("Proxy")
        .WithOpenApi();

    // Proxy endpoint for placing orders
    proxyGroup.MapPost("/orders", async (
        [FromBody] Order order,
        IHttpClientFactory httpClientFactory,
        ILogger<Program> logger,
        CancellationToken cancellationToken) =>
    {
        using var activity = new ActivitySource("eShop.Orders.App.Proxy")
            .StartActivity("ProxyPlaceOrder", ActivityKind.Client);

        activity?.SetTag("order.id", order.Id);
        activity?.SetTag("order.total", order.Total);
        activity?.SetTag("order.quantity", order.Quantity);

        try
        {
            var client = httpClientFactory.CreateClient("orders-api");
            
            logger.LogInformation(
                "Proxying order placement request for OrderId: {OrderId}",
                order.Id);

            var response = await client.PostAsJsonAsync("/api/orders", order, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<Order>(cancellationToken);
                
                activity?.SetStatus(ActivityStatusCode.Ok);
                logger.LogInformation(
                    "Successfully proxied order placement for OrderId: {OrderId}",
                    order.Id);

                return Results.Ok(new { success = true, message = "Order placed successfully!", data = result });
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                var errorMessage = $"Failed to place order: {(int)response.StatusCode} - {errorContent}";

                activity?.SetStatus(ActivityStatusCode.Error, errorMessage);
                logger.LogWarning(
                    "Failed to proxy order placement for OrderId: {OrderId}. Status: {StatusCode}",
                    order.Id,
                    response.StatusCode);

                return Results.Problem(
                    statusCode: (int)response.StatusCode,
                    detail: errorContent,
                    title: "Order placement failed");
            }
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            logger.LogError(ex, "HTTP error while proxying order placement for OrderId: {OrderId}", order.Id);
            
            return Results.Problem(
                statusCode: StatusCodes.Status502BadGateway,
                detail: "Unable to reach Orders API",
                title: "Service unavailable");
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            logger.LogError(ex, "Unexpected error while proxying order placement for OrderId: {OrderId}", order.Id);
            
            return Results.Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                detail: ex.Message,
                title: "Internal server error");
        }
    })
    .WithName("ProxyPlaceOrder")
    .WithSummary("Proxy endpoint for placing orders via the Orders API")
    .WithDescription("Accepts order details from the WebAssembly client and forwards them to the Orders API using Aspire service discovery")
    .Produces<object>(StatusCodes.Status200OK)
    .ProducesProblem(StatusCodes.Status400BadRequest)
    .ProducesProblem(StatusCodes.Status502BadGateway)
    .ProducesProblem(StatusCodes.Status500InternalServerError);
}