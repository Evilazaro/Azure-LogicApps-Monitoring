using Aspire.Hosting;
using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Azure;
using Microsoft.Extensions.Hosting;
using Projects;

var builder = DistributedApplication.CreateBuilder(args);


//if (builder.Environment.IsDevelopment())
//{
//    sb = builder.AddAzureServiceBus("messaging").RunAsEmulator();
//}
//else
//{
    var appInsightsName = builder.Configuration.GetSection("AZURE_APPLICATION_INSIGHTS_NAME").Value;
    var existingAppInsights = builder.AddParameter("Application-Insights", appInsightsName);

    var sbName = builder.Configuration.GetSection("AZURE_SERVICE_BUS_NAMESPACE").Value;
    var existingSb = builder.AddParameter("Service-Bus", sbName);

    var resourceGroupName = builder.Configuration.GetSection("AZURE_RESOURCE_GROUP").Value;
    var existingRg = builder.AddParameter("Resource-Group", resourceGroupName);

    var sb = builder.AddAzureServiceBus("Messaging")
        .AsExisting(existingSb, existingRg);
    sb.AddServiceBusQueue("orders-queue");

    var appInsights = builder.AddAzureApplicationInsights("Telemetry")
        .AsExisting(existingAppInsights, existingRg);

//}

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    //.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", eShopOrders.AppHost.Constants.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .WithReference(sb)
    .WithReference(appInsights)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
    .WithEnvironment("AZURE_TENANT_ID", builder.Configuration.GetSection("AZURE_TENANT_ID").Value ?? "")
    .WithEnvironment("AZURE_CLIENT_ID", builder.Configuration.GetSection("AZURE_CLIENT_ID").Value ?? "")
    .AsHttp2Service()
    .WithExternalHttpEndpoints();

var ordersWebApp = builder.AddProject<eShop_Orders_App>("orders-webapp")
    //.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", eShopOrders.AppHost.Constants.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .WithReference(appInsights)
    .WithReference(ordersApi).WaitFor(ordersApi)
    .AsHttp2Service()
    .WithExternalHttpEndpoints();

builder.Build().Run();
