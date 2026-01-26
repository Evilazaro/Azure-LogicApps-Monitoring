// =============================================================================
// Unit Tests for OrderService
// Tests business logic layer for order management operations
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Services;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace eShop.Orders.API.Tests.Services;

/// <summary>
/// Unit tests for <see cref="OrderService"/> class.
/// Verifies business logic behavior with mocked dependencies.
/// </summary>
[TestClass]
[DoNotParallelize]
public sealed class OrderServiceTests : IDisposable
{
    private ILogger<OrderService> _logger = null!;
    private IOrderRepository _orderRepository = null!;
    private IOrdersMessageHandler _ordersMessageHandler = null!;
    private IServiceScopeFactory _serviceScopeFactory = null!;
    private IServiceScope _serviceScope = null!;
    private IServiceProvider _scopedServiceProvider = null!;
    private ActivitySource _activitySource = null!;
    private IMeterFactory _meterFactory = null!;
    private OrderService _orderService = null!;

    private const string TestOrderId = "order-12345";
    private const string TestCustomerId = "customer-67890";
    private const string TestDeliveryAddress = "123 Test Street, Test City, TC 12345";

    [TestInitialize]
    public void TestInitialize()
    {
        _logger = Substitute.For<ILogger<OrderService>>();
        _orderRepository = Substitute.For<IOrderRepository>();
        _ordersMessageHandler = Substitute.For<IOrdersMessageHandler>();
        _serviceScopeFactory = Substitute.For<IServiceScopeFactory>();
        _serviceScope = Substitute.For<IServiceScope>();
        _scopedServiceProvider = Substitute.For<IServiceProvider>();
        _activitySource = new ActivitySource("Tests.OrderService");
        _meterFactory = Substitute.For<IMeterFactory>();

        // Setup meter factory to return a real meter - use ReturnsForAnyArgs to avoid Arg.Any leaking in parallel tests
        _meterFactory.Create(default!).ReturnsForAnyArgs(new Meter("TestMeter"));

        // Setup service scope factory
        _serviceScopeFactory.CreateScope().Returns(_serviceScope);
        _serviceScope.ServiceProvider.Returns(_scopedServiceProvider);
        _scopedServiceProvider.GetService(typeof(IOrderRepository)).Returns(_orderRepository);
        _scopedServiceProvider.GetService(typeof(IOrdersMessageHandler)).Returns(_ordersMessageHandler);

        _orderService = new OrderService(
            _logger,
            _orderRepository,
            _ordersMessageHandler,
            _serviceScopeFactory,
            _activitySource,
            _meterFactory);
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _orderService.Dispose();
        _activitySource.Dispose();
    }

    public void Dispose()
    {
        _orderService?.Dispose();
        _activitySource?.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderService(
                null!,
                _orderRepository,
                _ordersMessageHandler,
                _serviceScopeFactory,
                _activitySource,
                _meterFactory));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullOrderRepository_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderService(
                _logger,
                null!,
                _ordersMessageHandler,
                _serviceScopeFactory,
                _activitySource,
                _meterFactory));

        Assert.AreEqual("orderRepository", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullOrdersMessageHandler_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderService(
                _logger,
                _orderRepository,
                null!,
                _serviceScopeFactory,
                _activitySource,
                _meterFactory));

        Assert.AreEqual("ordersMessageHandler", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullServiceScopeFactory_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderService(
                _logger,
                _orderRepository,
                _ordersMessageHandler,
                null!,
                _activitySource,
                _meterFactory));

        Assert.AreEqual("serviceScopeFactory", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullActivitySource_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderService(
                _logger,
                _orderRepository,
                _ordersMessageHandler,
                _serviceScopeFactory,
                null!,
                _meterFactory));

        Assert.AreEqual("activitySource", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullMeterFactory_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrderService(
                _logger,
                _orderRepository,
                _ordersMessageHandler,
                _serviceScopeFactory,
                _activitySource,
                null!));

        Assert.AreEqual("meterFactory", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidParameters_CreatesInstance()
    {
        // Arrange & Act
        using var service = new OrderService(
            _logger,
            _orderRepository,
            _ordersMessageHandler,
            _serviceScopeFactory,
            _activitySource,
            _meterFactory);

        // Assert
        Assert.IsNotNull(service);
        Assert.IsInstanceOfType<IOrderService>(service);
    }

    #endregion

    #region PlaceOrderAsync Tests

    [TestMethod]
    public async Task PlaceOrderAsync_ValidOrder_ReturnsPlacedOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _orderService.PlaceOrderAsync(order, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
        Assert.AreEqual(order.CustomerId, result.CustomerId);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_ValidOrder_SavesOrderToRepository()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        await _orderService.PlaceOrderAsync(order, CancellationToken.None);

        // Assert
        await _orderRepository.Received(1).SaveOrderAsync(order, Arg.Any<CancellationToken>());
    }

    [TestMethod]
    public async Task PlaceOrderAsync_ValidOrder_SendsMessageToServiceBus()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        await _orderService.PlaceOrderAsync(order, CancellationToken.None);

        // Assert
        await _ordersMessageHandler.Received(1).SendOrderMessageAsync(order, Arg.Any<CancellationToken>());
    }

    [TestMethod]
    public async Task PlaceOrderAsync_NullOrder_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _orderService.PlaceOrderAsync(null!, CancellationToken.None));

        Assert.AreEqual("order", exception.ParamName);
    }

    [TestMethod]
    public async Task PlaceOrderAsync_OrderAlreadyExists_ThrowsInvalidOperationException()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<InvalidOperationException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "already exists");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder() with { Id = "" };

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "Order ID");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_EmptyCustomerId_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder() with { CustomerId = "" };

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "Customer ID");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_ZeroTotal_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder() with { Total = 0 };

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "total");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_NegativeTotal_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder() with { Total = -10.00m };

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "total");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_EmptyProducts_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder() with { Products = new List<OrderProduct>() };

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "product");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_NullProducts_ThrowsArgumentException()
    {
        // Arrange
        var order = CreateTestOrder() with { Products = null! };

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));

        StringAssert.Contains(exception.Message, "product");
    }

    [TestMethod]
    public async Task PlaceOrderAsync_RepositoryThrowsException_PropagatesException()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));
        _orderRepository.SaveOrderAsync(order, Arg.Any<CancellationToken>())
            .ThrowsAsync(new InvalidOperationException("Database error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<InvalidOperationException>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_MessageHandlerThrowsException_PropagatesException()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));
        _ordersMessageHandler.SendOrderMessageAsync(order, Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Service Bus error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<Exception>(
            () => _orderService.PlaceOrderAsync(order, CancellationToken.None));
    }

    [TestMethod]
    public async Task PlaceOrderAsync_CancellationRequested_ThrowsOperationCanceledException()
    {
        // Arrange
        var order = CreateTestOrder();
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .ThrowsAsync(new OperationCanceledException());

        // Act & Assert
        await Assert.ThrowsExactlyAsync<OperationCanceledException>(
            () => _orderService.PlaceOrderAsync(order, cts.Token));
    }

    #endregion

    #region PlaceOrdersBatchAsync Tests

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_ValidOrders_ReturnsSuccessfulOrders()
    {
        // Arrange
        var orders = CreateTestOrders(3);
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _orderService.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert
        var resultList = result.ToList();
        Assert.HasCount(3, resultList);
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_NullOrders_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _orderService.PlaceOrdersBatchAsync(null!, CancellationToken.None));

        Assert.AreEqual("orders", exception.ParamName);
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_EmptyOrders_ThrowsArgumentException()
    {
        // Arrange
        var orders = new List<Order>();

        // Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.PlaceOrdersBatchAsync(orders, CancellationToken.None));

        StringAssert.Contains(exception.Message, "empty");
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_SomeOrdersAlreadyExist_ReturnsAllOrders()
    {
        // Arrange
        var orders = CreateTestOrders(3);
        var existingOrder = orders[1];
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(call =>
            {
                var orderId = call.Arg<string>();
                return Task.FromResult(orderId == existingOrder.Id ? existingOrder : null);
            });

        // Act
        var result = await _orderService.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert - Should return all orders (successful + already existing)
        var resultList = result.ToList();
        Assert.HasCount(3, resultList);
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_SingleOrder_ProcessesSuccessfully()
    {
        // Arrange
        var orders = CreateTestOrders(1);
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _orderService.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert
        Assert.AreEqual(1, result.Count());
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_LargeBatch_ProcessesInBatches()
    {
        // Arrange - Create more than 50 orders to test batching
        var orders = CreateTestOrders(75);
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _orderService.PlaceOrdersBatchAsync(orders, CancellationToken.None);

        // Assert
        Assert.AreEqual(75, result.Count());
    }

    [TestMethod]
    public async Task PlaceOrdersBatchAsync_CancellationRequested_StopsProcessing()
    {
        // Arrange
        var orders = CreateTestOrders(10);
        using var cts = new CancellationTokenSource();
        var processedCount = 0;

        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(async call =>
            {
                processedCount++;
                if (processedCount >= 2)
                {
                    cts.Cancel();
                }
                await Task.Delay(10);
                return (Order?)null;
            });

        // Act
        var result = await _orderService.PlaceOrdersBatchAsync(orders, cts.Token);

        // Assert - Should have fewer than all orders processed
        var resultCount = result.Count();
        Assert.IsTrue(resultCount < 10 && resultCount >= 0, $"Expected fewer than 10 orders when cancellation was requested, got {resultCount}");
    }

    #endregion

    #region GetOrdersAsync Tests

    [TestMethod]
    public async Task GetOrdersAsync_OrdersExist_ReturnsAllOrders()
    {
        // Arrange
        var orders = CreateTestOrders(5);
        _orderRepository.GetAllOrdersAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(orders));

        // Act
        var result = await _orderService.GetOrdersAsync(CancellationToken.None);

        // Assert
        Assert.AreEqual(5, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_NoOrders_ReturnsEmptyCollection()
    {
        // Arrange
        _orderRepository.GetAllOrdersAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(new List<Order>()));

        // Act
        var result = await _orderService.GetOrdersAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task GetOrdersAsync_RepositoryThrowsException_PropagatesException()
    {
        // Arrange
        _orderRepository.GetAllOrdersAsync(Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<Exception>(
            () => _orderService.GetOrdersAsync(CancellationToken.None));
    }

    [TestMethod]
    public async Task GetOrdersAsync_CancellationRequested_ThrowsOperationCanceledException()
    {
        // Arrange
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        _orderRepository.GetAllOrdersAsync(Arg.Any<CancellationToken>())
            .ThrowsAsync(new OperationCanceledException());

        // Act & Assert
        await Assert.ThrowsExactlyAsync<OperationCanceledException>(
            () => _orderService.GetOrdersAsync(cts.Token));
    }

    #endregion

    #region GetOrderByIdAsync Tests

    [TestMethod]
    public async Task GetOrderByIdAsync_ExistingOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));

        // Act
        var result = await _orderService.GetOrderByIdAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(order.Id, result.Id);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_NonExistingOrder_ReturnsNull()
    {
        // Arrange
        _orderRepository.GetOrderByIdAsync("non-existing", Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _orderService.GetOrderByIdAsync("non-existing", CancellationToken.None);

        // Assert
        Assert.IsNull(result);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.GetOrderByIdAsync(null!, CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.GetOrderByIdAsync("", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_WhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.GetOrderByIdAsync("   ", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task GetOrderByIdAsync_RepositoryThrowsException_PropagatesException()
    {
        // Arrange
        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<Exception>(
            () => _orderService.GetOrderByIdAsync("test-id", CancellationToken.None));
    }

    #endregion

    #region DeleteOrderAsync Tests

    [TestMethod]
    public async Task DeleteOrderAsync_ExistingOrder_ReturnsTrue()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderRepository.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(true));

        // Act
        var result = await _orderService.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsTrue(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_ExistingOrder_CallsRepositoryDelete()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderRepository.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(true));

        // Act
        await _orderService.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Assert
        await _orderRepository.Received(1).DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>());
    }

    [TestMethod]
    public async Task DeleteOrderAsync_NonExistingOrder_ReturnsFalse()
    {
        // Arrange
        _orderRepository.GetOrderByIdAsync("non-existing", Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _orderService.DeleteOrderAsync("non-existing", CancellationToken.None);

        // Assert
        Assert.IsFalse(result);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_NonExistingOrder_DoesNotCallRepositoryDelete()
    {
        // Arrange
        _orderRepository.GetOrderByIdAsync("non-existing", Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        await _orderService.DeleteOrderAsync("non-existing", CancellationToken.None);

        // Assert
        await _orderRepository.DidNotReceive().DeleteOrderAsync(Arg.Any<string>(), Arg.Any<CancellationToken>());
    }

    [TestMethod]
    public async Task DeleteOrderAsync_NullOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.DeleteOrderAsync(null!, CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_EmptyOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.DeleteOrderAsync("", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_WhitespaceOrderId_ThrowsArgumentException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentException>(
            () => _orderService.DeleteOrderAsync("   ", CancellationToken.None));

        Assert.AreEqual("orderId", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrderAsync_RepositoryThrowsException_PropagatesException()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderRepository.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<Exception>(
            () => _orderService.DeleteOrderAsync(order.Id, CancellationToken.None));
    }

    [TestMethod]
    public async Task DeleteOrderAsync_RepositoryDeleteFails_ReturnsFalse()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderRepository.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderRepository.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(false));

        // Act
        var result = await _orderService.DeleteOrderAsync(order.Id, CancellationToken.None);

        // Assert
        Assert.IsFalse(result);
    }

    #endregion

    #region DeleteOrdersBatchAsync Tests

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_ValidOrderIds_ReturnsDeletedCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult<Order?>(CreateTestOrder(call.Arg<string>())));
        _orderRepository.DeleteOrderAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(true));

        // Act
        var result = await _orderService.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);

        // Assert
        Assert.AreEqual(3, result);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_NullOrderIds_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = await Assert.ThrowsExactlyAsync<ArgumentNullException>(
            () => _orderService.DeleteOrdersBatchAsync(null!, CancellationToken.None));

        Assert.AreEqual("orderIds", exception.ParamName);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_EmptyOrderIds_ReturnsZero()
    {
        // Arrange
        var orderIds = new List<string>();

        // Act
        var result = await _orderService.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);

        // Assert
        Assert.AreEqual(0, result);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_SomeOrdersNotFound_ReturnsPartialCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "non-existing", "order-3" };
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(call =>
            {
                var orderId = call.Arg<string>();
                return orderId == "non-existing"
                    ? Task.FromResult<Order?>(null)
                    : Task.FromResult<Order?>(CreateTestOrder(orderId));
            });
        _orderRepository.DeleteOrderAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(true));

        // Act
        var result = await _orderService.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);

        // Assert
        Assert.AreEqual(2, result);
    }

    [TestMethod]
    public async Task DeleteOrdersBatchAsync_PartialFailures_ContinuesWithOthers()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };
        SetupScopedServicesForBatch();

        _orderRepository.GetOrderByIdAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(call => Task.FromResult<Order?>(CreateTestOrder(call.Arg<string>())));
        _orderRepository.DeleteOrderAsync(Arg.Any<string>(), Arg.Any<CancellationToken>())
            .Returns(call =>
            {
                var orderId = call.Arg<string>();
                if (orderId == "order-2")
                {
                    throw new Exception("Delete failed");
                }
                return Task.FromResult(true);
            });

        // Act
        var result = await _orderService.DeleteOrdersBatchAsync(orderIds, CancellationToken.None);

        // Assert - Should have 2 successful deletes
        Assert.AreEqual(2, result);
    }

    #endregion

    #region ListMessagesFromTopicsAsync Tests

    [TestMethod]
    public async Task ListMessagesFromTopicsAsync_MessagesExist_ReturnsMessages()
    {
        // Arrange
        var messages = new List<object> { new { Id = "msg-1" }, new { Id = "msg-2" } };
        _ordersMessageHandler.ListMessagesAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<object>>(messages));

        // Act
        var result = await _orderService.ListMessagesFromTopicsAsync(CancellationToken.None);

        // Assert
        Assert.AreEqual(2, result.Count());
    }

    [TestMethod]
    public async Task ListMessagesFromTopicsAsync_NoMessages_ReturnsEmptyCollection()
    {
        // Arrange
        _ordersMessageHandler.ListMessagesAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<object>>(new List<object>()));

        // Act
        var result = await _orderService.ListMessagesFromTopicsAsync(CancellationToken.None);

        // Assert
        Assert.IsNotNull(result);
        Assert.AreEqual(0, result.Count());
    }

    [TestMethod]
    public async Task ListMessagesFromTopicsAsync_HandlerThrowsException_PropagatesException()
    {
        // Arrange
        _ordersMessageHandler.ListMessagesAsync(Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Service Bus error"));

        // Act & Assert
        await Assert.ThrowsExactlyAsync<Exception>(
            () => _orderService.ListMessagesFromTopicsAsync(CancellationToken.None));
    }

    #endregion

    #region Dispose Tests

    [TestMethod]
    public void Dispose_CalledMultipleTimes_DoesNotThrow()
    {
        // Arrange
        using var service = new OrderService(
            _logger,
            _orderRepository,
            _ordersMessageHandler,
            _serviceScopeFactory,
            _activitySource,
            _meterFactory);

        // Act & Assert - Should not throw
        service.Dispose();
        service.Dispose();
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string? orderId = null, int productCount = 1)
    {
        var id = orderId ?? TestOrderId;
        return new Order
        {
            Id = id,
            CustomerId = TestCustomerId,
            Date = DateTime.UtcNow,
            DeliveryAddress = TestDeliveryAddress,
            Total = productCount * 25.99m,
            Products = Enumerable.Range(1, productCount)
                .Select(i => new OrderProduct
                {
                    Id = $"{id}-product-{i}",
                    OrderId = id,
                    ProductId = $"product-{i}",
                    ProductDescription = $"Test Product {i}",
                    Quantity = i,
                    Price = 25.99m
                })
                .ToList()
        };
    }

    private static List<Order> CreateTestOrders(int count)
    {
        return Enumerable.Range(1, count)
            .Select(i => CreateTestOrder($"order-{i}"))
            .ToList();
    }

    private void SetupScopedServicesForBatch()
    {
        // Setup the service scope factory to return a real scope that provides our mocked services
        var scopeFactory = Substitute.For<IServiceScopeFactory>();
        var scope = Substitute.For<IServiceScope>();
        var serviceProvider = Substitute.For<IServiceProvider>();

        scopeFactory.CreateScope().Returns(scope);
        scopeFactory.CreateAsyncScope().Returns(new AsyncServiceScope(scope));
        scope.ServiceProvider.Returns(serviceProvider);
        serviceProvider.GetService(typeof(IOrderRepository)).Returns(_orderRepository);
        serviceProvider.GetService(typeof(IOrdersMessageHandler)).Returns(_ordersMessageHandler);
        serviceProvider.GetRequiredService(typeof(IOrderRepository)).Returns(_orderRepository);
        serviceProvider.GetRequiredService(typeof(IOrdersMessageHandler)).Returns(_ordersMessageHandler);

        // Re-create the order service with the new scope factory
        _orderService.Dispose();
        _orderService = new OrderService(
            _logger,
            _orderRepository,
            _ordersMessageHandler,
            scopeFactory,
            _activitySource,
            _meterFactory);
    }

    #endregion
}
