using Projects;

var builder = DistributedApplication.CreateBuilder(args);

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    //.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", eShopOrders.AppHost.Constants.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
    .AsHttp2Service()
    .WithExternalHttpEndpoints();

var ordersWebApp = builder.AddProject<eShop_Orders_App>("orders-webapp")
    //.WithEnvironment("APPLICATIONINSIGHTS_CONNECTION_STRING", eShopOrders.AppHost.Constants.APPLICATIONINSIGHTS_CONNECTION_STRING)
    .WithReference(ordersApi).WaitFor(ordersApi)
    .AsHttp2Service()
    .WithExternalHttpEndpoints();

builder.Build().Run();
