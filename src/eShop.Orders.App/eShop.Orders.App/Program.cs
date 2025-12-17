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

// Configure HTTP client for Orders API with service discovery
// The configuration key is automatically provided by Aspire based on the service reference
builder.Services.AddHttpClient("orders-api", client =>
{
    var baseUrl = builder.Configuration["services:orders-api:https:0"] 
                  ?? builder.Configuration["services:orders-api:http:0"]
                  ?? throw new InvalidOperationException("Orders API service URL not found in configuration");
    
    client.BaseAddress = new Uri(baseUrl);
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
