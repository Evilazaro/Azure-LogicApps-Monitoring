using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Handlers;
using Microsoft.Extensions.Logging;

namespace eShop.Oders.API.Tests.Handlers;

[TestClass]
public sealed class NoOpOrdersMessageHandlerTests
{
    private Mock<ILogger<NoOpOrdersMessageHandler>> _loggerMock = null!;
    private NoOpOrdersMessageHandler _handler = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        _loggerMock = new Mock<ILogger<NoOpOrdersMessageHandler>>();
        _handler = new NoOpOrdersMessageHandler(_loggerMock.Object);
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.ThrowsException<ArgumentNullException>(() => new NoOpOrdersMessageHandler(null!));
    }

    [TestMethod]
    public void Constructor_WithValidLogger_CreatesInstance()
    {
        // Arrange & Act
        var handler = new NoOpOrdersMessageHandler(_loggerMock.Object);

        // Assert
        Assert.IsNotNull(handler);
    }

    #endregion

    #region SendOrderMessageAsync Tests

    [TestMethod]
    public async Task SendOrderMessageAsync_WithValidOrder_CompletesSuccessfully()
    {
        // Arrange
        var order = CreateValidOrder();

        // Act
        await _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert - verify logging was called
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Would send order message")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsExceptionAsync<ArgumentNullException>(
            () => _handler.SendOrderMessageAsync(null!, CancellationToken.None));
    }

    [TestMethod]
    public async Task SendOrderMessageAsync_ReturnsCompletedTask()
    {
        // Arrange
        var order = CreateValidOrder();

        // Act
        var task = _handler.SendOrderMessageAsync(order, CancellationToken.None);

        // Assert
        Assert.IsTrue(task.IsCompletedSuccessfully);
        await task;
    }

    #endregion

    #region SendOrdersBatchMessageAsync Tests

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithValidOrders_CompletesSuccessfully()
    {
        // Arrange
        var orders = new List<Order> { CreateValidOrder(), CreateValidOrder("order-2") };

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert - verify logging was called with correct count
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Would send batch of 2 order messages")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithNullOrders_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsExceptionAsync<ArgumentNullException>(
            () => _handler.SendOrdersBatchMessageAsync(null!, CancellationToken.None));
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithEmptyOrders_LogsZeroCount()
    {
        // Arrange
        var orders = new List<Order>();

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Would send batch of 0 order messages")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithICollectionOrders_UsesOptimizedCount()
    {
        // Arrange - Use List<Order> which implements ICollection<Order>
        var orders = new List<Order>
        {
            CreateValidOrder("order-1"),
            CreateValidOrder("order-2"),
            CreateValidOrder("order-3")
        };

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Would send batch of 3 order messages")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_WithEnumerableOrders_CountsCorrectly()
    {
        // Arrange - Use an IEnumerable that is not ICollection to test the fallback Count()
        var orders = Enumerable.Range(1, 5).Select(i => CreateValidOrder($"order-{i}"));

        // Act
        await _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Would send batch of 5 order messages")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task SendOrdersBatchMessageAsync_ReturnsCompletedTask()
    {
        // Arrange
        var orders = new List<Order> { CreateValidOrder() };

        // Act
        var task = _handler.SendOrdersBatchMessageAsync(orders, CancellationToken.None);

        // Assert
        Assert.IsTrue(task.IsCompletedSuccessfully);
        await task;
    }

    #endregion

    #region ListMessagesAsync Tests

    [TestMethod]
    public async Task ListMessagesAsync_ReturnsEmptyEnumerable()
    {
        // Act
        var result = await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.IsFalse(result.Any());
    }

    [TestMethod]
    public async Task ListMessagesAsync_LogsInformationMessage()
    {
        // Act
        await _handler.ListMessagesAsync(CancellationToken.None);

        // Assert
        _loggerMock.Verify(
            x => x.Log(
                LogLevel.Information,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v.ToString()!.Contains("Would list messages from topics")),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Once);
    }

    [TestMethod]
    public async Task ListMessagesAsync_WithCancellationToken_CompletesSuccessfully()
    {
        // Arrange
        using var cts = new CancellationTokenSource();

        // Act
        var result = await _handler.ListMessagesAsync(cts.Token);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    #endregion

    #region Helper Methods

    private static Order CreateValidOrder(string orderId = "order-1")
    {
        return new Order
        {
            Id = orderId,
            CustomerId = "customer-1",
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Main St, City, Country",
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = "product-item-1",
                    OrderId = orderId,
                    ProductId = "product-1",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.99m
                }
            ]
        };
    }

    #endregion
}