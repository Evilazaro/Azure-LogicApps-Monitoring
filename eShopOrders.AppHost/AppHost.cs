using Aspire.Hosting.Azure;
using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Configure resources based on environment
var resources = ConfigureInfrastructureResources(builder);
ConfigureServices(builder, resources);

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
    // Configuration keys as constants for maintainability
    const string AppInsightsNameKey = "AZURE_APPLICATION_INSIGHTS_NAME";
    const string ServiceBusNamespaceKey = "AZURE_SERVICE_BUS_NAMESPACE";
    const string ResourceGroupKey = "AZURE_RESOURCE_GROUP";
    const string TenantIdKey = "AZURE_TENANT_ID";
    const string ClientIdKey = "AZURE_CLIENT_ID";

    // Validate and retrieve required configuration
    var appInsightsName = GetRequiredConfiguration(builder, AppInsightsNameKey);
    var serviceBusNamespace = GetRequiredConfiguration(builder, ServiceBusNamespaceKey);
    var resourceGroupName = GetRequiredConfiguration(builder, ResourceGroupKey);

    // Validate authentication configuration
    _ = GetRequiredConfiguration(builder, TenantIdKey);
    _ = GetRequiredConfiguration(builder, ClientIdKey);

    // Create parameters for existing Azure resources
    var appInsightsParameter = builder.AddParameter("azure-application-insights", appInsightsName);
    var serviceBusParameter = builder.AddParameter("azure-service-bus", serviceBusNamespace);
    var resourceGroupParameter = builder.AddParameter("azure-resource-group", resourceGroupName);

    // Configure Service Bus with queue
    var serviceBus = builder.AddAzureServiceBus("messaging")
        .AsExisting(serviceBusParameter, resourceGroupParameter);

    // Add orders queue to the Service Bus namespace
    var ordersQueue = serviceBus.AddServiceBusQueue("orders-queue");

    // Configure Application Insights
    var appInsights = builder.AddAzureApplicationInsights("telemetry")
        .AsExisting(appInsightsParameter, resourceGroupParameter);

    return (AppInsights: appInsights, ServiceBus: serviceBus);
}

/// <summary>
/// Configures the Orders API and Web App services with appropriate references and settings.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="resources">Infrastructure resources to reference.</param>
static void ConfigureServices(
    IDistributedApplicationBuilder builder,
    (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus) resources)
{
    // Configuration keys
    const string TenantIdKey = "AZURE_TENANT_ID";
    const string ClientIdKey = "AZURE_CLIENT_ID";

    // Configure Orders API
    var ordersApiBuilder = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
        .WithEnvironment("ASPNETCORE_ENVIRONMENT", builder.Environment.EnvironmentName);

    // Add Azure authentication configuration if available
    var tenantId = builder.Configuration[TenantIdKey];
    var clientId = builder.Configuration[ClientIdKey];

    if (!string.IsNullOrWhiteSpace(tenantId))
    {
        ordersApiBuilder.WithEnvironment(TenantIdKey, tenantId);
    }

    if (!string.IsNullOrWhiteSpace(clientId))
    {
        ordersApiBuilder.WithEnvironment(ClientIdKey, clientId);
    }

    // Add Service Bus reference if available (production only)
    if (resources.ServiceBus != null)
    {
        ordersApiBuilder.WithReference(resources.ServiceBus);
    }

    // Add Application Insights reference if available (production only)
    if (resources.AppInsights != null)
    {
        ordersApiBuilder.WithReference(resources.AppInsights);
    }

    var ordersApi = ordersApiBuilder
        .WithHttpsEndpoint(port: null, name: "api-https")
        .WithExternalHttpEndpoints();

    // Configure Orders Web App (Blazor WebAssembly)
    var ordersWebAppBuilder = builder.AddProject<Projects.eShop_Orders_App>("orders-webapp")
        .WithReference(ordersApi)
        .WaitFor(ordersApi);

    // Add Application Insights reference if available (production only)
    if (resources.AppInsights != null)
    {
        ordersWebAppBuilder.WithReference(resources.AppInsights);
    }

    ordersWebAppBuilder
        .WithEnvironment(ClientIdKey, clientId)
        .WithEnvironment(TenantIdKey, tenantId)
        .WithHttpsEndpoint(port: null, name: "webapp-https")
        .WithExternalHttpEndpoints();
}

/// <summary>
/// Retrieves a required configuration value and throws if it's missing or empty.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <param name="key">The configuration key to retrieve.</param>
/// <returns>The configuration value.</returns>
/// <exception cref="InvalidOperationException">Thrown when the configuration value is missing or empty.</exception>
static string GetRequiredConfiguration(IDistributedApplicationBuilder builder, string key)
{
    var value = builder.Configuration[key];

    if (string.IsNullOrWhiteSpace(value))
    {
        throw new InvalidOperationException(
            $"Required configuration '{key}' is missing or empty. " +
            $"Please ensure it's set in your configuration (appsettings.json, user secrets, or environment variables).");
    }

    return value;
}