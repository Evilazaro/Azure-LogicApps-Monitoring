var builder = DistributedApplication.CreateBuilder(args);

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("eshop-orders-api")
                       .WithExternalHttpEndpoints()
                       .AsHttp2Service();

var webApp = builder.AddProject<Projects.eShop_Web_App>("eshop-web-app")
                    .WithExternalHttpEndpoints()
                    .WithReference(ordersAPI)
                    .AsHttp2Service();

builder.Build().Run();
