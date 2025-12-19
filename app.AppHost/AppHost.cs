var builder = DistributedApplication.CreateBuilder(args);

var ordersAPI = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
                       .WithHttpHealthCheck("/health");

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
                    .WithExternalHttpEndpoints()
                    .WithHttpHealthCheck("/health")
                    .WithReference(ordersAPI)
                    .WithReplicas(2)
                    .WaitFor(ordersAPI);

builder.Build().Run();
