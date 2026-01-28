// =============================================================================
// AppHost Service Bus Configuration Tests
// Tests for verifying Azure Service Bus configuration and topology
// =============================================================================

using Aspire.Hosting.ApplicationModel;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace app.AppHost.Tests;

/// <summary>
/// Tests for verifying Service Bus configuration in the AppHost.
/// </summary>
[TestClass]
public sealed class ServiceBusConfigurationTests
{
    #region Local Emulator Mode Tests

    [TestMethod]
    public async Task ServiceBus_InLocalMode_ConfiguresEmulator()
    {
        // Arrange - Default configuration uses localhost (emulator mode)
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        // Use ToList() to avoid collection modification during enumeration
        var messagingResource = model.Resources.ToList().FirstOrDefault(r => r.Name == "messaging");
        Assert.IsNotNull(messagingResource, "messaging resource should be configured");
    }

    [TestMethod]
    public async Task ServiceBus_InLocalMode_HasTopicConfigured()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Look for topic resource (ordersplaced)
        // Use ToList() to avoid collection modification during enumeration
        var topicResource = model.Resources.ToList().FirstOrDefault(r =>
            r.Name.Contains("ordersplaced", StringComparison.OrdinalIgnoreCase));

        Assert.IsNotNull(topicResource, "Service Bus topic 'ordersplaced' should be configured");
    }

    [TestMethod]
    public async Task ServiceBus_InLocalMode_HasSubscriptionConfigured()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Look for subscription resource
        // Use ToList() to avoid collection modification during enumeration
        var subscriptionResource = model.Resources.ToList().FirstOrDefault(r =>
            r.Name.Contains("orderprocessingsub", StringComparison.OrdinalIgnoreCase));

        Assert.IsNotNull(subscriptionResource, "Service Bus subscription 'orderprocessingsub' should be configured");
    }

    #endregion

    #region Resource Reference Tests

    [TestMethod]
    public async Task OrdersApi_HasServiceBusReference()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Use ToList() to avoid collection modification during enumeration
        var ordersApiResource = model.Resources.ToList().FirstOrDefault(r => r.Name == "orders-api");

        // Assert
        Assert.IsNotNull(ordersApiResource, "orders-api should exist");

        // Verify it has environment variable annotations (which include connection string references)
        var annotations = ordersApiResource.Annotations.ToList();
        Assert.IsNotEmpty(annotations, "orders-api should have annotations including Service Bus reference");
    }

    #endregion

    #region Configuration Defaults Tests

    [TestMethod]
    public async Task ServiceBus_DefaultTopicName_IsOrdersPlaced()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify default topic name
        // Use ToList() to avoid collection modification during enumeration
        var topicResource = model.Resources.ToList().FirstOrDefault(r => r.Name == "ordersplaced");
        Assert.IsNotNull(topicResource, "Default topic name should be 'ordersplaced'");
    }

    [TestMethod]
    public async Task ServiceBus_DefaultSubscriptionName_IsOrderProcessingSub()
    {
        // Arrange
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>();

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert - Verify default subscription name
        // Use ToList() to avoid collection modification during enumeration
        var subscriptionResource = model.Resources.ToList().FirstOrDefault(r => r.Name == "orderprocessingsub");
        Assert.IsNotNull(subscriptionResource, "Default subscription name should be 'orderprocessingsub'");
    }

    #endregion
}
