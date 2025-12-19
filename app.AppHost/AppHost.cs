var builder = DistributedApplication.CreateBuilder(args);

var enableAppInsights = builder.AddParameterFromConfiguration("UseApplicationInsights", "ApplicationInsights:Enabled");
var appInsightsConnString = builder.AddParameterFromConfiguration("ApplicationInsightsConnectionString", "ApplicationInsights:ConnectionString");

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
                       .WithHttpHealthCheck("/health");

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
                    .WithExternalHttpEndpoints()
                    .WithHttpHealthCheck("/health")
                    .WithReference(ordersAPI)
                    .WaitFor(ordersAPI);

// Conditionally enable Application Insights based on configuration
if (bool.TryParse(builder.Configuration["ApplicationInsights:Enabled"], out var isEnabled) && isEnabled)
{
    ordersAPI.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
    webApp.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
}

builder.Build().Run();
