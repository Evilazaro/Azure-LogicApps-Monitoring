var builder = DistributedApplication.CreateBuilder(args);

builder.AddProject<Projects.eShop_Orders_App>("orders-app");

builder.AddProject<Projects.eShop_Orders_API>("orders-api");


builder.Build().Run();
