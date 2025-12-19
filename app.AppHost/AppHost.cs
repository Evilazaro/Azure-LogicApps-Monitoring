var builder = DistributedApplication.CreateBuilder(args);

var appInsightsConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
                       .WithHttpHealthCheck("/health")
                       .WithEnvironment("APPINSIGHTS_CONNECTION_STRING", appInsightsConnectionString);

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
                    .WithExternalHttpEndpoints()
                    .WithHttpHealthCheck("/health")
                    .WithReference(ordersAPI)
                    .WithEnvironment("APPINSIGHTS_CONNECTION_STRING", appInsightsConnectionString)
                    .WaitFor(ordersAPI);

builder.Build().Run();
