var builder = DistributedApplication.CreateBuilder(args);

builder.AddProject<Projects.eShop_Web_App>("eshop-web-app");

builder.Build().Run();
