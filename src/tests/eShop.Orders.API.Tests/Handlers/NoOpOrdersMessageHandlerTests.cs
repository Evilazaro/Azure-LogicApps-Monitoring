// =============================================================================
// Unit Tests for NoOpOrdersMessageHandler
// Tests no-operation stub implementation for development environments
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Handlers;
using eShop.Orders.API.Interfaces;
using Microsoft.Extensions.Logging;
using NSubstitute;

namespace eShop.Orders.API.Tests.Handlers;

/// <summary>
/// Unit tests for <see cref="NoOpOrdersMessageHandler"/> class.
/// Verifies the no-operation stub correctly logs and returns without errors.
/// </summary>
[TestClass]
public sealed class NoOpOrdersMessageHandlerTests
{
    private ILogger<NoOpOrdersMessageHandler> _logger = null!;
    private NoOpOrdersMessageHandler _handler = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        _logger = Substitute.For<ILogger<NoOpOrdersMessageHandler>>();
        _handler = new NoOpOrdersMessageHandler(_logger);
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(
            () => new NoOpOrdersMessageHandler(null!));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidLogger_CreatesInstance()
    {
        // Arrange & Act
        var handler = new NoOpOrdersMessageHandler(_logger);

        // Assert
        Assert.IsNotNull(handler);
        Assert.IsInstanceOfType<IOrdersMessageHandler>(handler);
    }

    #endregion

    #region SendOrderMessageAsync Tests

    [TestMethod]
    public async Task SendOrderMessageAsync_ValidOrder_CompletesSuccessfully()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert - No exception means success
        _logger.ReceivedWithAnyArgs(1).LogInformation(default);
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_NullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _handler.SendOrderMessageAsync(null!, CancellationToken.None));

        Assert.AreEqual("order", exception.ParamName);
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_CancellationRequested_DoesNotThrow()
    {
        // Arrange
        var order = CreateTestOrder();
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        // Act - NoOp handler ignores cancellation token
        await _handler.SendOrderMessageAsync(order, cts.Token);

        // Assert - Completes without exception
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_MultipleOrders_CompletesEachSuccessfully()
    {
        // Arrange
        var orders = Enumerable.Range(1, 5).Select(i => CreateTestOrder($"order-{i}")).ToList();

        // Act
        foreach (var order in orders)
        {
            await _handler.SendOrderMessageAsync(order, CancellationToken.None);
        }

        // Assert - Should log for each order
        _logger.ReceivedWithAnyArgs(5).LogInformation(default);
    }

    #endregion

    #region SendOrdersBatchMessageAsync Tests

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_ValidOrders_CompletesSuccessfully()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2"),
            CreateTestOrder("order-3")
        };

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        _logger.ReceivedWithAnyArgs(1).LogInformation(default);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_NullOrders_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _handler.SendOrdersBatchMessageAsync(null!, CancellationToken.None));

        Assert.AreEqual("orders", exception.ParamName);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_EmptyCollection_CompletesSuccessfully()
    {
        // Arrange
        var emptyOrders = Enumerable.Empty<Order>();

        // Act
        await _handler.SendOrdersBatchMessageAsync(emptyOrders, CancellationToken.None);

        // Assert - Logs count of 0
        _logger.ReceivedWithAnyArgs(1).LogInformation(default);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_CancellationRequested_DoesNotThrow()
    {
        // Arrange
        var orders = new List<Order> { CreateTestOrder() };
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, cts.Token);

        // Assert - Completes without exception
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_ListCollection_UsesCountProperty()
    {
        // Arrange - Use a List<Order> which implements ICollection<Order>
        var orders = new List<Order>
        {
            CreateTestOrder("order-1"),
            CreateTestOrder("order-2")
        };

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert - Should complete and log
        _logger.ReceivedWithAnyArgs(1).LogInformation(default);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_EnumerableCollection_UsesLinqCount()
    {
        // Arrange - Use an IEnumerable that's not ICollection
        var orders = Enumerable.Range(1, 3).Select(i => CreateTestOrder($"order-{i}"));

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert - Should complete and log
        _logger.ReceivedWithAnyArgs(1).LogInformation(default);
    }

    #endregion

    #region ListMessagesAsync Tests

    [TestMethod]
    public async Task ListMessagesAsync_ReturnsEmptyCollection()
    {
        // Arrange & Act
        var result = await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.IsFalse(result.Any());
    }

    [TestMethod]
    public async Task ListMessagesAsync_CancellationRequested_DoesNotThrow()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        await cts.CancelAsync();

        // Act
        var result = await _handler.ListMessagesAsync(cts.Token);

        // Assert
        Assert.IsNotNull(result);
        Assert.IsFalse(result.Any());
    }

    [TestMethod]
    public async Task ListMessagesAsync_MultipleCalls_ReturnsSameResult()
    {
        // Arrange & Act
        var result1 = await _handler.ListMessagesAsync(CancellationToken.None);
        var result2 = await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result1);
        Assert.IsNotNull(result2);
        Assert.AreEqual(result1.Count(), result2.Count());
    }

    [TestMethod]
    public async Task ListMessagesAsync_LogsOperation()
    {
        // Arrange & Act
        await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        _logger.ReceivedWithAnyArgs(1).LogInformation(default);
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string? orderId = null) => new()
    {
        Id = orderId ?? $"order-{Guid.NewGuid():N}",
        CustomerId = $"customer-{Guid.NewGuid():N}",
        Date = DateTime.UtcNow,
        DeliveryAddress = "456 NoOp Lane, Dev City, DC 00000",
        Total = 150.00m,
        Products =
        [
            new OrderProduct
            {
                Id = $"product-item-{Guid.NewGuid():N}",
                OrderId = orderId ?? "order-1",
                ProductId = $"product-{Guid.NewGuid():N}",
                ProductDescription = "NoOp Test Product",
                Quantity = 1,
                Price = 150.00m
            }
        ]
    };

    #endregion
}