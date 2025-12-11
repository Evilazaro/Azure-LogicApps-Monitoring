var builder = DistributedApplication.CreateBuilder(args);

builder.AddProject<Projects.eShop_Orders_App>("eshop-orders-app");

builder.Build().Run();
