using Aspire.Hosting.Azure;
using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");
var ordersWebApp = builder.AddProject<Projects.eShop_Orders_App>("orders-webapp");

// Configure resources based on environment
var resources = ConfigureInfrastructureResources(builder);
ConfigureServices(builder, ordersApi, ordersWebApp, resources);

await builder.Build().RunAsync();

/// <summary>
/// Configures infrastructure resources (Application Insights, Service Bus) based on the environment.
/// In non-development environments, references existing Azure resources.
/// In development, uses local development emulators or in-memory alternatives.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing configured infrastructure resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus)
    ConfigureInfrastructureResources(IDistributedApplicationBuilder builder)
{
    if (builder.Environment.IsDevelopment())
    {
        return ConfigureProductionResources(builder);
    }

    // In development, Application Insights and Service Bus are optional
    // OpenTelemetry will use OTLP exporter to Aspire Dashboard
    return (AppInsights: null, ServiceBus: null);
}

/// <summary>
/// Configures Azure resources for production environments using existing infrastructure.
/// Retrieves configuration from user secrets, appsettings, or environment variables.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>Configured Application Insights and Service Bus resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource> AppInsights, IResourceBuilder<AzureServiceBusResource> ServiceBus)
    ConfigureProductionResources(IDistributedApplicationBuilder builder)
{
    // Get values from configuration (user secrets, appsettings, or environment variables)
    // Aspire automatically loads from these sources in order:
    // 1. User secrets (dotnet user-secrets)
    // 2. appsettings.json / appsettings.{Environment}.json
    // 3. Environment variables
    var appInsightsName = builder.Configuration["Azure:ApplicationInsights:Name"];
    var serviceBusNamespace = builder.Configuration["Azure:ServiceBus:Namespace"]; 
    var resourceGroupName = builder.Configuration["Azure:ResourceGroup"];

    // Validate required configuration
    if (string.IsNullOrWhiteSpace(appInsightsName))
        throw new InvalidOperationException("Azure Application Insights name is not configured. Set 'Azure:ApplicationInsights:Name' in user secrets or configuration.");
    if (string.IsNullOrWhiteSpace(serviceBusNamespace))
        throw new InvalidOperationException("Azure Service Bus namespace is not configured. Set 'Azure:ServiceBus:Namespace' in user secrets or configuration.");
    if (string.IsNullOrWhiteSpace(resourceGroupName))
        throw new InvalidOperationException("Azure Resource Group is not configured. Set 'Azure:ResourceGroup' in user secrets or configuration.");

    // Create parameters for Azure resources
    var appInsightsParameter = builder.AddParameter("azure-application-insights", appInsightsName);
    var serviceBusParameter = builder.AddParameter("azure-service-bus", serviceBusNamespace);
    var resourceGroupParameter = builder.AddParameter("azure-resource-group", resourceGroupName);

    // Configure Service Bus with queue
    var serviceBus = builder.AddAzureServiceBus("messaging")
        .AsExisting(serviceBusParameter, resourceGroupParameter);

    // Add orders queue to the Service Bus namespace
    serviceBus.AddServiceBusQueue("orders-queue");

    // Configure Application Insights
    var appInsights = builder.AddAzureApplicationInsights("telemetry")
        .AsExisting(appInsightsParameter, resourceGroupParameter);

    return (AppInsights: appInsights, ServiceBus: serviceBus);
}

/// <summary>
/// Configures the Orders API and Web App services with appropriate references and settings.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="ordersApi">The Orders API project resource.</param>
/// <param name="ordersWebApp">The Orders Web App project resource.</param>
/// <param name="resources">Infrastructure resources to reference.</param>
static void ConfigureServices(
    IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi,
    IResourceBuilder<ProjectResource> ordersWebApp,
    (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus) resources)
{
    // Get authentication configuration from secrets
    var tenantId = builder.Configuration["Azure:TenantId"] 
        ?? builder.Configuration["AZURE_TENANT_ID"];
    var clientId = builder.Configuration["Azure:ClientId"] 
        ?? builder.Configuration["AZURE_CLIENT_ID"];

    // Configure Orders API
    ordersApi.WithEnvironment("ASPNETCORE_ENVIRONMENT", builder.Environment.EnvironmentName);

    // Only add authentication config if values are present
    if (!string.IsNullOrWhiteSpace(tenantId))
    {
        ordersApi.WithEnvironment("AZURE_TENANT_ID", tenantId);
    }

    if (!string.IsNullOrWhiteSpace(clientId))
    {
        ordersApi.WithEnvironment("AZURE_CLIENT_ID", clientId);
    }

    // Add Service Bus reference if available (production only)
    if (resources.ServiceBus != null)
    {
        ordersApi.WithReference(resources.ServiceBus);
    }

    // Add Application Insights reference if available (production only)
    if (resources.AppInsights != null)
    {
        ordersApi.WithReference(resources.AppInsights);
    }

    ordersApi.WithHttpsEndpoint(port: null, name: "api-https")
              .WithExternalHttpEndpoints();

    // Configure Orders Web App (Blazor WebAssembly)
    ordersWebApp.WithReference(ordersApi)
        .WaitFor(ordersApi);

    // Only add authentication config if values are present
    if (!string.IsNullOrWhiteSpace(tenantId))
    {
        ordersWebApp.WithEnvironment("AZURE_TENANT_ID", tenantId);
    }

    if (!string.IsNullOrWhiteSpace(clientId))
    {
        ordersWebApp.WithEnvironment("AZURE_CLIENT_ID", clientId);
    }

    // Add Application Insights reference if available (production only)
    if (resources.AppInsights != null)
    {
        ordersWebApp.WithReference(resources.AppInsights);
    }

    ordersWebApp.WithHttpsEndpoint(port: null, name: "webapp-https")
                .WithExternalHttpEndpoints();
}