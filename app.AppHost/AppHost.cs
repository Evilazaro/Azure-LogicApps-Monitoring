using Aspire.Hosting;
using Aspire.Hosting.Azure;
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
    var appInsightsParam = builder.AddParameter("ApplicationInsights", appInsightsConnString);
    var rgParam = builder.AddParameter("resourceGroup", builder.Configuration["Azure:ResourceGroup"] ?? string.Empty);
    var appInsights = builder.AddAzureApplicationInsights(appInsightsConnString).AsExisting(appInsightsParam, rgParam);
    ordersAPI.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
    webApp.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", appInsightsConnString);
}

var sbHostName = builder.Configuration["Azure:ServiceBus:HostName"] ?? string.Empty;

if (!string.IsNullOrEmpty(sbHostName))
{
    sbHostName = "sb-localhost";
    var sbParam = builder.AddParameter("messaging", sbHostName);
    var sb = builder.AddAzureServiceBus(sbHostName);

    sb.AddServiceBusTopic("OrdersPlaced")
      .AddServiceBusSubscription("OrderProcessing");

    sb.RunAsEmulator();

    ordersAPI.WithReference(sb);
}
else
{
    var sbParam = builder.AddParameter("messaging", sbHostName);
    var rgParam = builder.AddParameter("resourceGroup", builder.Configuration["Azure:ResourceGroup"] ?? string.Empty);
    var sb = builder.AddAzureServiceBus(sbHostName).AsExisting(sbParam, rgParam);

    ordersAPI.WithReference(sb);
}



builder.Build().Run();
