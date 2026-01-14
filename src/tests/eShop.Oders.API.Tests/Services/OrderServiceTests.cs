using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Diagnostics;

namespace eShop.Oders.API.Tests.Services;

[TestClass]
public sealed class OrderServiceTests
{
    private Mock<ILogger<OrderService>> _loggerMock = null!;
    private Mock<IOrderRepository> _orderRepositoryMock = null!;
    private Mock<IOrdersMessageHandler> _ordersMessageHandlerMock = null!;
    private Mock<IServiceScopeFactory> _serviceScopeFactoryMock = null!;
    private ActivitySource _activitySource = null!;
    private OrderService _orderService = null!;

    [TestInitialize]
    public void TestInitialize()
    {
        _loggerMock = new Mock<ILogger<OrderService>>();
        _orderRepositoryMock = new Mock<IOrderRepository>();
        _ordersMessageHandlerMock = new Mock<IOrdersMessageHandler>();
        _serviceScopeFactoryMock = new Mock<IServiceScopeFactory>();
        _activitySource = new ActivitySource("eShop.Orders.API.Tests");

        _orderService = new OrderService(
            _loggerMock.Object,
            _orderRepositoryMock.Object,
            _ordersMessageHandlerMock.Object,
            _serviceScopeFactoryMock.Object,
            _activitySource);
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _activitySource.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_WithNullLogger_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => new OrderService(
            null!,
            _orderRepositoryMock.Object,
            _ordersMessageHandlerMock.Object,
            _serviceScopeFactoryMock.Object,
            _activitySource));
    }

    [TestMethod]
    public void Constructor_WithNullRepository_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => new OrderService(
            _loggerMock.Object,
            null!,
            _ordersMessageHandlerMock.Object,
            _serviceScopeFactoryMock.Object,
            _activitySource));
    }

    [TestMethod]
    public void Constructor_WithNullMessageHandler_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => new OrderService(
            _loggerMock.Object,
            _orderRepositoryMock.Object,
            null!,
            _serviceScopeFactoryMock.Object,
            _activitySource));
    }

    [TestMethod]
    public void Constructor_WithNullServiceScopeFactory_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => new OrderService(
            _loggerMock.Object,
            _orderRepositoryMock.Object,
            _ordersMessageHandlerMock.Object,
            null!,
            _activitySource));
    }

    [TestMethod]
    public void Constructor_WithNullActivitySource_ThrowsArgumentNullException()
    {
        // Act & Assert
        Assert.ThrowsExactly<ArgumentNullException>(() => new OrderService(
            _loggerMock.Object,
            _orderRepositoryMock.Object,
            _ordersMessageHandlerMock.Object,
            _serviceScopeFactoryMock.Object,
            null!));
    }

    #endregion

    #region PlaceOrderAsync Tests

    [TestMethod]
    public async Task PlaceOrderAsync_WithValidOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateValidOrder();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Order?)null);
        _orderRepositoryMock.Setup(r => r.SaveOrderAsync(order, It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        _ordersMessageHandlerMock.Setup(m => m.SendOrderMessageAsync(order, It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        // Act
        var result = await _orderService.PlaceOrderAsync(order);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
        _orderRepositoryMock.Verify(r => r.SaveOrderAsync(order, It.IsAny<CancellationToken>()), Times.Once);
        _ordersMessageHandlerMock.Verify(m => m.SendOrderMessageAsync(order, It.IsAny<CancellationToken>()), Times.Once);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithNullOrder_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _orderService.PlaceOrderAsync(null!));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithExistingOrder_ThrowsInvalidOperationException()
    {
        // Arrange
        var order = CreateValidOrder();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(order);

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<InvalidOperationException>(
            () => _orderService.PlaceOrderAsync(order));
        Assert.IsTrue(exception.Message.Contains("already exists"));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateOrderWithEmptyId();

        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithEmptyCustomerId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateOrderWithEmptyCustomerId();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Order?)null);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithZeroTotal_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateOrderWithZeroTotal();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Order?)null);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_WithNoProducts_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateOrderWithNoProducts();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Order?)null);

        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order));
    }

    #endregion

    #region PlaceOrdersBatchAsync Tests

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_WithNullOrders_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _orderService.PlaceOrdersBatchAsync(null!));
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_WithEmptyOrders_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrdersBatchAsync([]));
    }

    #endregion

    #region GetOrdersAsync Tests

    [TestMethod]
    public async Task GetOrdersAsync_ReturnsAllOrders()
    {
        // Arrange
        var orders = new List<Order> { CreateValidOrder(), CreateValidOrder("order-2") };
        _orderRepositoryMock.Setup(r => r.GetAllOrdersAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(orders);

        // Act
        var result = await _orderService.GetOrdersAsync();

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(2, result.Count());
        _orderRepositoryMock.Verify(r => r.GetAllOrdersAsync(It.IsAny<CancellationToken>()), Times.Once);
    }

    [TestMethod]
    public async Task GetOrdersAsync_WhenRepositoryThrows_PropagatesException()
    {
        // Arrange
        _orderRepositoryMock.Setup(r => r.GetAllOrdersAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Database error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<InvalidOperationException>(
            () => _orderService.GetOrdersAsync());
    }

    #endregion

    #region GetOrderByIdAsync Tests

    [TestMethod]
    public async Task GetOrderByIdAsync_WithExistingOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateValidOrder();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(order);

        // Act
        var result = await _orderService.GetOrderByIdAsync(order.Id);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithNonExistingOrder_ReturnsNull()
    {
        // Arrange
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync("non-existing", It.IsAny<CancellationToken>()))
            .ReturnsAsync((Order?)null);

        // Act
        var result = await _orderService.GetOrderByIdAsync("non-existing");

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithNullOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.GetOrderByIdAsync(null!));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.GetOrderByIdAsync(string.Empty));
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WithWhitespaceOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.GetOrderByIdAsync("   "));
    }

    #endregion

    #region DeleteOrderAsync Tests

    [TestMethod]
    public async Task DeleteOrderAsync_WithExistingOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateValidOrder();
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(order);
        _orderRepositoryMock.Setup(r => r.DeleteOrderAsync(order.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        // Act
        var result = await _orderService.DeleteOrderAsync(order.Id);

        // Assert
        Assert.IsTrue(result);
        _orderRepositoryMock.Verify(r => r.DeleteOrderAsync(order.Id, It.IsAny<CancellationToken>()), Times.Once);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithNonExistingOrder_ReturnsFalse()
    {
        // Arrange
        _orderRepositoryMock.Setup(r => r.GetOrderByIdAsync("non-existing", It.IsAny<CancellationToken>()))
            .ReturnsAsync((Order?)null);

        // Act
        var result = await _orderService.DeleteOrderAsync("non-existing");

        // Assert
        Assert.IsFalse(result);
        _orderRepositoryMock.Verify(r => r.DeleteOrderAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithNullOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.DeleteOrderAsync(null!));
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WithEmptyOrderId_ThrowsArgumentException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.DeleteOrderAsync(string.Empty));
    }

    #endregion

    #region DeleteOrdersBatchAsync Tests

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_WithNullOrderIds_ThrowsArgumentNullException()
    {
        // Act & Assert
        await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _orderService.DeleteOrdersBatchAsync(null!, CancellationToken.None));
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_WithEmptyOrderIds_ReturnsZero()
    {
        // Act
        var result = await _orderService.DeleteOrdersBatchAsync([], CancellationToken.None);

        // Assert
        Assert.AreEqual(0, result);
    }

    #endregion

    #region ListMessagesFromTopicsAsync Tests

    [TestMethod]
    public async Task ListMessagesFromTopicsAsync_ReturnsMessages()
    {
        // Arrange
        var messages = new List<object> { new { Id = "1" }, new { Id = "2" } };
        _ordersMessageHandlerMock.Setup(m => m.ListMessagesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(messages);

        // Act
        var result = await _orderService.ListMessagesFromTopicsAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task ListMessagesFromTopicsAsync_WhenHandlerThrows_PropagatesException()
    {
        // Arrange
        _ordersMessageHandlerMock.Setup(m => m.ListMessagesAsync(It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("Service Bus error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<InvalidOperationException>(
            () => _orderService.ListMessagesFromTopicsAsync(CancellationToken.None));
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

    private static Order CreateOrderWithEmptyId()
    {
        return new Order
        {
            Id = string.Empty,
            CustomerId = "customer-1",
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Main St, City, Country",
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = "product-item-1",
                    OrderId = "",
                    ProductId = "product-1",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.99m
                }
            ]
        };
    }

    private static Order CreateOrderWithEmptyCustomerId()
    {
        return new Order
        {
            Id = "order-1",
            CustomerId = string.Empty,
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Main St, City, Country",
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = "product-item-1",
                    OrderId = "order-1",
                    ProductId = "product-1",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.99m
                }
            ]
        };
    }

    private static Order CreateOrderWithZeroTotal()
    {
        return new Order
        {
            Id = "order-1",
            CustomerId = "customer-1",
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Main St, City, Country",
            Total = 0m,
            Products =
            [
                new OrderProduct
                {
                    Id = "product-item-1",
                    OrderId = "order-1",
                    ProductId = "product-1",
                    ProductDescription = "Test Product",
                    Quantity = 2,
                    Price = 49.99m
                }
            ]
        };
    }

    private static Order CreateOrderWithNoProducts()
    {
        return new Order
        {
            Id = "order-1",
            CustomerId = "customer-1",
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Main St, City, Country",
            Total = 99.99m,
            Products = []
        };
    }

    #endregion
}