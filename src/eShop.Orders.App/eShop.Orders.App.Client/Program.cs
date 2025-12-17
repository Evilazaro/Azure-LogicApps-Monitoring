using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

builder.Services.AddScoped(sp => new HttpClient 
{ 
    BaseAddress = new Uri(builder.Configuration["ORDERS_API_HTTPS"] ?? throw new InvalidOperationException("OrdersApi:BaseUrl configuration is missing.")) 
});

await builder.Build().RunAsync();
