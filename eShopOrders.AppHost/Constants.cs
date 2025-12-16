// ------------------------------------------------------------------------------
// <copyright file="Constants.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Application-wide constants for the AppHost.
// </summary>
// ------------------------------------------------------------------------------

namespace eShopOrders.AppHost;

/// <summary>
/// Defines application-wide constants for configuration and templating.
/// </summary>
public static class Constants
{
    /// <summary>
    /// Template placeholder for Application Insights connection string.
    /// Replaced at runtime with actual environment variable value.
    /// </summary>
    public const string APPLICATIONINSIGHTS_CONNECTION_STRING = "{{ .Env.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING }}";
}
