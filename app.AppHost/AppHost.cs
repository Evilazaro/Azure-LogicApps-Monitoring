using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
                       .WithHttpHealthCheck("/health");

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
                    .WithExternalHttpEndpoints()
                    .WithHttpHealthCheck("/health")
                    .WithReference(ordersAPI)
                    .WaitFor(ordersAPI);

var appInsightsConnString = builder.Configuration["ApplicationInsights:ConnectionString"] ?? string.Empty;

if (!string.IsNullOrEmpty(appInsightsConnString))
{
    ordersAPI.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
    webApp.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
}


builder.Build().Run();
