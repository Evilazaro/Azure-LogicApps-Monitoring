// ------------------------------------------------------------------------------
// <copyright file="ConfigurationKeys.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Centralized configuration key constants for type-safe configuration access.
// </summary>
// ------------------------------------------------------------------------------

namespace eShopOrders.AppHost.Configuration;

/// <summary>
/// Configuration key constants for the Orders application.
/// Centralizes all configuration keys for easier maintenance and refactoring.
/// </summary>
/// <remarks>
/// Using constants instead of magic strings provides:
/// - Compile-time checking
/// - IntelliSense support
/// - Easier refactoring across the codebase
/// </remarks>
public static class ConfigurationKeys
{
    /// <summary>
    /// Azure Application Insights resource name.
    /// </summary>
    public const string ApplicationInsightsName = "AZURE_APPLICATION_INSIGHTS_NAME";

    /// <summary>
    /// Azure Service Bus namespace name.
    /// </summary>
    public const string ServiceBusNamespace = "AZURE_SERVICE_BUS_NAMESPACE";

    /// <summary>
    /// Azure resource group name.
    /// </summary>
    public const string ResourceGroup = "AZURE_RESOURCE_GROUP";

    /// <summary>
    /// Azure tenant ID for authentication.
    /// </summary>
    public const string TenantId = "AZURE_TENANT_ID";

    /// <summary>
    /// Azure client ID (application ID) for authentication.
    /// </summary>
    public const string ClientId = "AZURE_CLIENT_ID";
}

/// <summary>
/// Resource name constants for Aspire application resources.
/// </summary>
public static class ResourceNames
{
    /// <summary>
    /// Application Insights resource name in Aspire.
    /// </summary>
    public const string Telemetry = "telemetry";

    /// <summary>
    /// Service Bus resource name in Aspire.
    /// </summary>
    public const string Messaging = "messaging";

    /// <summary>
    /// Service Bus queue name for orders.
    /// </summary>
    public const string OrdersTopic = "OrderPlaced";

    /// <summary>
    /// Orders API service name.
    /// </summary>
    public const string OrdersApi = "orders-api";

    /// <summary>
    /// Orders Web App service name.
    /// </summary>
    public const string OrdersWebApp = "orders-webapp";
}