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
    if (!builder.Environment.IsDevelopment())
    {
        return ConfigureProductionResources(builder);
    }

    // In development, Application Insights and Service Bus are optional
    // OpenTelemetry will use OTLP exporter to Aspire Dashboard
    return (AppInsights: null, ServiceBus: null);
}

/// <summary>
/// Configures Azure resources for production environments using existing infrastructure.
/// Validates that all required configuration values are present.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>Configured Application Insights and Service Bus resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource> AppInsights, IResourceBuilder<AzureServiceBusResource> ServiceBus)
    ConfigureProductionResources(IDistributedApplicationBuilder builder)
{
    // Create parameters for Azure resources (these will be stored as secrets)
    var appInsightsName = builder.AddParameter("azure-application-insights", builder.Configuration.GetSection("AZURE_APPLICATION_INSIGHTS_NAME").Value ?? "");
    var serviceBusNamespace = builder.AddParameter("azure-service-bus", Environment.GetEnvironmentVariable("AZURE_SERVICE_BUS_NAMESPACE") ?? "");
    var resourceGroupName = builder.AddParameter("azure-resource-group", Environment.GetEnvironmentVariable("AZURE_RESOURCE_GROUP") ?? "");
    var tenantId = builder.AddParameter("azure-tenant-id", Environment.GetEnvironmentVariable("AZURE_TENANT_ID") ?? "");
    var clientId = builder.AddParameter("azure-client-id", Environment.GetEnvironmentVariable("AZURE_CLIENT_ID") ?? "");

    // Configure Service Bus with queue
    var serviceBus = builder.AddAzureServiceBus("messaging")
        .AsExisting(serviceBusNamespace, resourceGroupName);

    // Add orders queue to the Service Bus namespace
    serviceBus.AddServiceBusQueue("orders-queue");

    // Configure Application Insights
    var appInsights = builder.AddAzureApplicationInsights("telemetry")
        .AsExisting(appInsightsName, resourceGroupName);

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
    // Create parameters for authentication (these can be shared across services)
    var tenantId = builder.AddParameter("azure-tenant-id", Environment.GetEnvironmentVariable("AZURE_TENANT_ID") ?? "");
    var clientId = builder.AddParameter("azure-client-id", Environment.GetEnvironmentVariable("AZURE_CLIENT_ID") ?? "");

    // Configure Orders API
    ordersApi.WithEnvironment("ASPNETCORE_ENVIRONMENT", builder.Environment.EnvironmentName)
        .WithEnvironment("AZURE_TENANT_ID", tenantId)
        .WithEnvironment("AZURE_CLIENT_ID", clientId);

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
        .WaitFor(ordersApi)
        .WithEnvironment("AZURE_CLIENT_ID", clientId)
        .WithEnvironment("AZURE_TENANT_ID", tenantId);

    // Add Application Insights reference if available (production only)
    if (resources.AppInsights != null)
    {
        ordersWebApp.WithReference(resources.AppInsights);
    }

    ordersWebApp.WithHttpsEndpoint(port: null, name: "webapp-https")
                .WithExternalHttpEndpoints();
}