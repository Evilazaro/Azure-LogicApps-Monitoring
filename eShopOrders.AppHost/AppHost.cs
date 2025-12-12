using Aspire.Hosting;
using Aspire.Hosting.Azure;
using Projects;


var builder = DistributedApplication.CreateBuilder(args);

var appInsights = builder.AddAzureApplicationInsights("app-insights");

var outputs = appInsights.Resource.ConnectionString;

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", outputs)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development");

var ordersWebApp = builder.AddProject<eShop_Orders_App>("orders-webapp")
    .WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", outputs)
    .WithReference(ordersApi).WaitFor(ordersApi);

builder.Build().Run();
