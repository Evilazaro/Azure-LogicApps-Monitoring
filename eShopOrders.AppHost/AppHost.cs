using Aspire.Hosting.Azure;
using Microsoft.Extensions.Hosting;
using System.Diagnostics;

// ========== ActivitySource Management ==========
// Static ActivitySource ensures proper lifecycle management and prevents resource leaks
// This instance is reused throughout the application lifetime
var activitySource = new ActivitySource("eShop.Orders.AppHost");

// ========== Application Startup ==========
// Create root activity for AppHost startup tracing
using var startupActivity = activitySource.StartActivity("AppHost.Startup", ActivityKind.Internal);

try
{
    startupActivity?.SetTag("aspire.apphost", "eShopOrders");
    startupActivity?.SetTag("environment", Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT") ?? "Production");
    startupActivity?.SetTag("version", "1.0.0");

    var builder = DistributedApplication.CreateBuilder(args);

    ArgumentNullException.ThrowIfNull(builder);

    var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");
    var ordersWebApp = builder.AddProject<Projects.eShop_Orders_App>("orders-webapp");

    // ========== Resource Configuration ==========
    // Configure infrastructure resources based on environment
    using (var resourceActivity = activitySource.StartActivity("AppHost.ConfigureResources", ActivityKind.Internal))
    {
        try
        {
            resourceActivity?.SetTag("environment", builder.Environment.EnvironmentName);
            resourceActivity?.SetTag("is_development", builder.Environment.IsDevelopment());

            var resources = ConfigureInfrastructureResources(builder);
            resourceActivity?.AddEvent(new ActivityEvent("Infrastructure resources configured"));

            ConfigureServices(builder, ordersApi, ordersWebApp, resources);
            resourceActivity?.AddEvent(new ActivityEvent("Services configured"));

            resourceActivity?.SetStatus(ActivityStatusCode.Ok);
        }
        catch (Exception ex)
        {
            resourceActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            resourceActivity?.AddException(ex);
            throw;
        }
    }

    // ========== Application Build and Run ==========
    using (var buildActivity = activitySource.StartActivity("AppHost.Build", ActivityKind.Internal))
    {
        try
        {
            startupActivity?.SetStatus(ActivityStatusCode.Ok);
            startupActivity?.AddEvent(new ActivityEvent("AppHost startup completed"));

            await builder.Build().RunAsync();
        }
        catch (Exception ex)
        {
            buildActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            buildActivity?.AddException(ex);
            throw;
        }
    }
}
catch (Exception ex)
{
    startupActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
    startupActivity?.AddException(ex);
    Console.Error.WriteLine($"AppHost startup failed: {ex.Message}");
    throw;
}

// ========== Infrastructure Configuration Methods ==========

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
    ArgumentNullException.ThrowIfNull(builder);

    return builder.Environment.IsDevelopment()
        ? ConfigureDevelopmentResources(builder)
        : ConfigureProductionResources(builder);
}

/// <summary>
/// Configures Azure resources for development environments using local emulators or optional Azure resources.
/// Retrieves configuration from user secrets, appsettings, or environment variables.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>Configured Application Insights and Service Bus resources.</returns>
static (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource> ServiceBus)
    ConfigureDevelopmentResources(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    const string TelemetryParamName = "azure-application-insights-dev";
    const string TelemetryResourceName = "telemetry";
    const string MessagingParamName = "azure-service-bus-dev";
    const string MessagingResourceName = "messaging";
    const string ServiceBusDevParameterName = "service-bus-dev";
    const string ResourceGroupParameterName = "azure-resource-group-dev";

    // Get values from configuration (user secrets, appsettings, or environment variables)
    var config = GetAzureConfiguration(builder);

    IResourceBuilder<AzureApplicationInsightsResource>? appInsights = null;
    IResourceBuilder<AzureServiceBusResource>? serviceBus;
    IResourceBuilder<ParameterResource>? resourceGroupParameter = null;

    if (config.HasResourceGroupConfiguration)
    {
        resourceGroupParameter = builder.AddParameter(ResourceGroupParameterName, config.ResourceGroupName!);
    }

    // Configure Application Insights if configuration is available
    if (config.HasAppInsightsConfiguration)
    {
        var appInsightsParameter = builder.AddParameter(TelemetryParamName, config.AppInsightsName!);

        appInsights = builder.AddAzureApplicationInsights(TelemetryResourceName)
            .AsExisting(appInsightsParameter, resourceGroupParameter);
    }

    // Configure Service Bus - use emulator if no configuration is available
    if (config.HasServiceBusConfiguration)
    {
        var serviceBusParameter = builder.AddParameter(MessagingParamName, config.ServiceBusHostName!);

        serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
            .AsExisting(serviceBusParameter, resourceGroupParameter);
    }
    else
    {
        var serviceBusParameter = builder.AddParameter(MessagingParamName, ServiceBusDevParameterName);
        serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
            .RunAsEmulator();
    }

    // Add orders topic with subscription to the Service Bus namespace
    // The subscription is required for the API to receive messages from the topic
    var topicName = config.ServiceBusTopicName ?? "OrdersPlaced";
    var ordersTopic = serviceBus.AddServiceBusTopic(topicName);
    ordersTopic.AddServiceBusSubscription("OrderProcessingSubscription");

    return (AppInsights: appInsights, ServiceBus: serviceBus);
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
    ArgumentNullException.ThrowIfNull(builder);

    const string TelemetryResourceName = "telemetry";
    const string MessagingResourceName = "messaging";

    // Get and validate configuration
    var config = GetAzureConfiguration(builder);
    ValidateProductionConfiguration(config);

    // Create parameters for Azure resources
    var appInsightsParameter = builder.AddParameter("azure-application-insights", config.AppInsightsName!);
    var serviceBusParameter = builder.AddParameter("azure-service-bus", config.ServiceBusHostName!);
    var resourceGroupParameter = builder.AddParameter("azure-resource-group", config.ResourceGroupName!);

    // Configure Service Bus with topic and subscription
    var serviceBus = builder.AddAzureServiceBus(MessagingResourceName)
        .AsExisting(serviceBusParameter, resourceGroupParameter);

    // Add orders topic with subscription
    // Topic name should always be configured in production, but provide a default for safety
    var topicName = config.ServiceBusTopicName ?? "OrdersPlaced";
    var ordersTopic = serviceBus.AddServiceBusTopic(topicName);
    ordersTopic.AddServiceBusSubscription("OrderProcessingSubscription");

    // Configure Application Insights
    var appInsights = builder.AddAzureApplicationInsights(TelemetryResourceName)
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
    ArgumentNullException.ThrowIfNull(builder);
    ArgumentNullException.ThrowIfNull(ordersApi);
    ArgumentNullException.ThrowIfNull(ordersWebApp);

    // Configure Orders API
    ConfigureOrdersApi(builder,ordersApi, builder.Environment.EnvironmentName, resources);

    // Configure Orders Web App (Blazor WebAssembly)
    ConfigureOrdersWebApp(builder, ordersWebApp, ordersApi, resources.AppInsights);
}

/// <summary>
/// Configures the Orders API project with environment variables and resource references.
/// </summary>
static void ConfigureOrdersApi(IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersApi,
    string environmentName,
    (IResourceBuilder<AzureApplicationInsightsResource>? AppInsights, IResourceBuilder<AzureServiceBusResource>? ServiceBus) resources)
{

    var config = GetAzureConfiguration(builder);

    if(!string.IsNullOrEmpty(config.TenantId) && !string.IsNullOrEmpty(config.ClientId))
    {
        ordersApi.WithEnvironment("AZURE_TENANT_ID", config.TenantId);
        ordersApi.WithEnvironment("AZURE_CLIENT_ID", config.ClientId);
    }

    // Add Service Bus reference if available
    if (resources.ServiceBus is not null)
    {
        ordersApi
            .WithReference(resources.ServiceBus)
            .WaitFor(resources.ServiceBus);
    }

    // Add Application Insights reference if available
    if (resources.AppInsights is not null)
    {
        ordersApi
            .WithReference(resources.AppInsights)
            .WaitFor(resources.AppInsights);
    }

    ordersApi.AsHttp2Service();
}

/// <summary>
/// Configures the Orders Web App project with environment variables and resource references.
/// </summary>
static void ConfigureOrdersWebApp(IDistributedApplicationBuilder builder,
    IResourceBuilder<ProjectResource> ordersWebApp,
    IResourceBuilder<ProjectResource> ordersApi,
    IResourceBuilder<AzureApplicationInsightsResource>? appInsights)
{
    //    var config = GetAzureConfiguration(builder);

    //    if (!string.IsNullOrEmpty(config.TenantId) && !string.IsNullOrEmpty(config.ClientId))
    //    {
    //        ordersWebApp.WithEnvironment("AZURE_TENANT_ID", config.TenantId);
    //        ordersWebApp.WithEnvironment("AZURE_CLIENT_ID", config.ClientId);
    //    }

    // Add Application Insights reference if available
    if (appInsights is not null)
    {
        ordersWebApp.WithReference(appInsights)
                    .WaitFor(appInsights);
    }

    ordersWebApp.WithReference(ordersApi)
                .WaitFor(ordersApi)
                .AsHttp2Service();

    

}

/// <summary>
/// Retrieves Azure configuration from the builder's configuration sources.
/// </summary>
/// <param name="builder">The distributed application builder.</param>
/// <returns>A tuple containing Azure resource names and configuration status flags.</returns>
static (string? TenantId, string? ClientId, string? AppInsightsName, string? ServiceBusHostName, string? ServiceBusTopicName, string? ResourceGroupName, bool HasAzureAuthConfig, bool HasResourceGroupConfiguration, bool HasAppInsightsConfiguration, bool HasServiceBusConfiguration)
    GetAzureConfiguration(IDistributedApplicationBuilder builder)
{
    ArgumentNullException.ThrowIfNull(builder);

    var tenantId = builder.Configuration["Azure:TenantId"];
    var clientId = builder.Configuration["Azure:ClientId"];
    var appInsightsName = builder.Configuration["Azure:ApplicationInsights:Name"];
    var serviceBusHostName = builder.Configuration["Azure:ServiceBus:HostName"];
    var serviceBusTopicName = builder.Configuration["Azure:ServiceBus:TopicName"] ?? "OrdersPlaced";
    var resourceGroupName = builder.Configuration["Azure:ResourceGroup"];

    var hasAzureAuthConfig = !string.IsNullOrWhiteSpace(tenantId) && !string.IsNullOrEmpty(clientId);

    var hasAppInsightsConfig = !string.IsNullOrWhiteSpace(appInsightsName)
                             && !string.IsNullOrWhiteSpace(resourceGroupName);
    var hasServiceBusConfig = !string.IsNullOrWhiteSpace(serviceBusHostName)
                            && !string.IsNullOrWhiteSpace(resourceGroupName)
                            && !string.IsNullOrWhiteSpace(serviceBusTopicName);

    var hasResourceGroup = !string.IsNullOrWhiteSpace(resourceGroupName);

    return (tenantId, clientId, appInsightsName, serviceBusHostName, serviceBusTopicName, resourceGroupName, hasAzureAuthConfig, hasResourceGroup, hasAppInsightsConfig, hasServiceBusConfig);
}

/// <summary>
/// Validates that all required production configuration values are present.
/// </summary>
static void ValidateProductionConfiguration(
    (string? TenantId, string? ClientId, string? AppInsightsName, string? ServiceBusHostName, string? ServiceBusTopicName, string? ResourceGroupName, bool HasAzureAuthConfig, bool HasResourceGroupConfiguration, bool HasAppInsightsConfiguration, bool HasServiceBusConfiguration) config)
{
    if (!config.HasAzureAuthConfig)
    {
        throw new InvalidOperationException(
            "Azure authentication configuration is incomplete. Ensure 'Azure:TenantId' and 'Azure:ClientId' are set in user secrets or configuration.");
    }

    if (!config.HasAppInsightsConfiguration)
    {
        throw new InvalidOperationException(
            "Azure Application Insights configuration is incomplete. Ensure 'Azure:ApplicationInsights:Name' and 'Azure:ResourceGroup' are set in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.AppInsightsName))
    {
        throw new InvalidOperationException(
            "Azure Application Insights name is not configured. Set 'Azure:ApplicationInsights:Name' in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.ServiceBusHostName))
    {
        throw new InvalidOperationException(
            "Azure Service Bus namespace is not configured. Set 'Azure:ServiceBus:HostName' in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.ServiceBusTopicName))
    {
        throw new InvalidOperationException(
            "Azure Service Bus topic name is not configured. Set 'Azure:ServiceBus:TopicName' in user secrets or configuration.");
    }

    if (string.IsNullOrWhiteSpace(config.ResourceGroupName))
    {
        throw new InvalidOperationException(
            "Azure Resource Group is not configured. Set 'Azure:ResourceGroup' in user secrets or configuration.");
    }

    if (!config.HasServiceBusConfiguration)
    {
        throw new InvalidOperationException(
            "Azure Service Bus configuration is incomplete. Ensure 'Azure:ServiceBus:HostName', 'Azure:ServiceBus:TopicName', and 'Azure:ResourceGroup' are set in user secrets or configuration.");
    }
}