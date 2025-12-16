// ------------------------------------------------------------------------------
// <copyright file="Program.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Application entry point for the Orders Web App Client (Blazor WebAssembly).
//     Configures the WebAssembly host for client-side interactive components.
// </summary>
// ------------------------------------------------------------------------------

using Microsoft.AspNetCore.Components.WebAssembly.Hosting;

// Create WebAssembly host with default configuration
// Services and components are registered in the server project
// This client assembly provides the interactive UI components
var builder = WebAssemblyHostBuilder.CreateDefault(args);

// Build and run the WebAssembly application
await builder.Build().RunAsync();
