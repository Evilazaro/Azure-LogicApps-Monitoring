using eShop.Orders.App.Client.Services;
using Microsoft.Extensions.DependencyInjection;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using System;
using System.Collections.Generic;

namespace eShop.Orders.App.Client.Extensions;

/// <summary>
/// Extension methods for configuring services in the Blazor WebAssembly client.
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Adds order management services with OpenTelemetry instrumentation.
    /// </summary>
    /// <param name="services">The service collection to configure.</param>
    /// <param name="ordersApiBaseAddress">Base address of the Orders API.</param>
    /// <param name="isDevelopment">Indicates if the environment is development.</param>
    /// <returns>The configured service collection for method chaining.</returns>
    public static IServiceCollection AddOrderServices(
        this IServiceCollection services, 
        string ordersApiBaseAddress,
        bool isDevelopment = false)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentException.ThrowIfNullOrWhiteSpace(ordersApiBaseAddress);

        // Register HttpClient for OrderService
        services.AddHttpClient<OrderService>(client =>
        {
            client.BaseAddress = new Uri(ordersApiBaseAddress);
            client.DefaultRequestHeaders.Add("Accept", "application/json");
            client.Timeout = TimeSpan.FromSeconds(30);
        });

        // Configure OpenTelemetry for Blazor WebAssembly using modern API
        services.AddOpenTelemetry()
            .ConfigureResource(resource => resource
                .AddService(
                    serviceName: "eShop.Orders.Client",
                    serviceVersion: typeof(ServiceCollectionExtensions).Assembly.GetName().Version?.ToString() ?? "1.0.0")
                .AddAttributes(new Dictionary<string, object>
                {
                    ["service.namespace"] = "eShop.Orders",
                    ["deployment.environment"] = isDevelopment ? "development" : "production",
                    ["telemetry.sdk.language"] = "dotnet",
                    ["client.type"] = "blazor-webassembly"
                }))
            .WithTracing(tracing =>
            {
                tracing
                    .AddSource("eShop.Orders.Client")
                    .AddHttpClientInstrumentation(options =>
                    {
                        // Filter out health check and other non-business HTTP calls
                        options.FilterHttpRequestMessage = (httpRequestMessage) =>
                        {
                            var requestPath = httpRequestMessage.RequestUri?.PathAndQuery ?? string.Empty;
                            return !requestPath.Contains("_framework") && 
                                   !requestPath.Contains("_blazor");
                        };

                        // Enrich spans with additional context
                        options.EnrichWithHttpRequestMessage = (activity, request) =>
                        {
                            activity.SetTag("http.client", "blazor-wasm");
                            activity.SetTag("http.request.method", request.Method.ToString());
                            
                            if (request.RequestUri != null)
                            {
                                activity.SetTag("http.url", request.RequestUri.ToString());
                                activity.SetTag("url.scheme", request.RequestUri.Scheme);
                            }
                        };

                        options.EnrichWithHttpResponseMessage = (activity, response) =>
                        {
                            activity.SetTag("http.response.status_code", (int)response.StatusCode);
                            activity.SetTag("http.response.status_text", response.ReasonPhrase ?? "Unknown");
                        };

                        // Record exceptions for better error tracking
                        options.RecordException = true;
                    });

                // Add appropriate exporter based on environment
                if (isDevelopment)
                {
                    tracing.AddConsoleExporter();
                }
                else
                {
                    tracing.AddOtlpExporter(otlpOptions =>
                    {
                        // OTLP exporter configuration for Blazor WASM
                        // Note: Blazor WASM has limitations - consider using console exporter for development
                        otlpOptions.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.HttpProtobuf;
                    });
                }
            });

        return services;
    }
}