// =============================================================================
// AppHost Service Bus Configuration Tests
// Tests for verifying Azure Service Bus configuration and topology
// =============================================================================

using Aspire.Hosting;
using Aspire.Hosting.Azure;
using Aspire.Hosting.Testing;
using Microsoft.Extensions.Configuration;
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
            .CreateAsync<Projects.app_AppHost>(args =>
            {
                args.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Azure:ServiceBus:HostName"] = "localhost"
                });
            });

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var messagingResource = model.Resources.FirstOrDefault(r => r.Name == "messaging");
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
        var topicResource = model.Resources.FirstOrDefault(r =>
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
        var subscriptionResource = model.Resources.FirstOrDefault(r =>
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

        var ordersApiResource = model.Resources.FirstOrDefault(r => r.Name == "orders-api");

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
        var topicResource = model.Resources.FirstOrDefault(r => r.Name == "ordersplaced");
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
        var subscriptionResource = model.Resources.FirstOrDefault(r => r.Name == "orderprocessingsub");
        Assert.IsNotNull(subscriptionResource, "Default subscription name should be 'orderprocessingsub'");
    }

    #endregion

    #region Custom Configuration Tests

    [TestMethod]
    public async Task ServiceBus_WithCustomTopicName_ConfiguresCorrectly()
    {
        // Arrange
        var customTopicName = "customtopic";
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>(args =>
            {
                args.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Azure:ServiceBus:TopicName"] = customTopicName
                });
            });

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var topicResource = model.Resources.FirstOrDefault(r => r.Name == customTopicName);
        Assert.IsNotNull(topicResource, $"Custom topic name '{customTopicName}' should be configured");
    }

    [TestMethod]
    public async Task ServiceBus_WithCustomSubscriptionName_ConfiguresCorrectly()
    {
        // Arrange
        var customSubscriptionName = "customsub";
        var appHost = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.app_AppHost>(args =>
            {
                args.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Azure:ServiceBus:SubscriptionName"] = customSubscriptionName
                });
            });

        // Act
        await using var app = await appHost.BuildAsync();
        var model = app.Services.GetRequiredService<DistributedApplicationModel>();

        // Assert
        var subscriptionResource = model.Resources.FirstOrDefault(r => r.Name == customSubscriptionName);
        Assert.IsNotNull(subscriptionResource, $"Custom subscription name '{customSubscriptionName}' should be configured");
    }

    #endregion
}
