// ------------------------------------------------------------------------------
// <copyright file="Program.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Application entry point for the Orders Web App (Blazor Server).
//     Configures Razor Components with WebAssembly interactivity.
// </summary>
// ------------------------------------------------------------------------------

using eShop.Orders.App.Components;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyComponents();

var ordersHttpClient = builder.Services.AddHttpClient("orders-api", client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ORDERS_API_HTTPS"] ?? throw new InvalidOperationException("OrdersApi:BaseUrl configuration is missing."));
    client.DefaultRequestHeaders.Add("Accept", "application/json");
});

var app = builder.Build();

app.MapDefaultEndpoints();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseWebAssemblyDebugging();
}
else
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();


app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(eShop.Orders.App.Client._Imports).Assembly);

app.Run();
