var builder = DistributedApplication.CreateBuilder(args);

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("eshop-orders-api");

var webApp = builder.AddProject<Projects.eShop_Web_App>("eshop-web-app")
                    .WithReference(ordersAPI)
                    .WaitFor(ordersAPI);

builder.Build().Run();
