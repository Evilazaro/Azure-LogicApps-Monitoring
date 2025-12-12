using Projects;

var builder = DistributedApplication.CreateBuilder(args);

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development");

var ordersWebApp = builder.AddProject<eShop_Orders_App>("orders-webapp")
    .WithReference(ordersApi).WaitFor(ordersApi);

builder.Build().Run();
