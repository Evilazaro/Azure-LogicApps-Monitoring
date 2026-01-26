// =============================================================================
// Unit Tests for OrdersController
// Tests API layer endpoints for order management operations
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Controllers;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using NSubstitute;
using NSubstitute.ExceptionExtensions;
using System.Diagnostics;

namespace eShop.Orders.API.Tests.Controllers;

/// <summary>
/// Unit tests for <see cref="OrdersController"/> class.
/// Verifies HTTP endpoint behavior with mocked dependencies.
/// </summary>
[TestClass]
[DoNotParallelize]
public sealed class OrdersControllerTests : IDisposable
{
    private ILogger<OrdersController> _logger = null!;
    private IOrderService _orderService = null!;
    private ActivitySource _activitySource = null!;
    private OrdersController _controller = null!;

    private const string TestOrderId = "order-12345";
    private const string TestCustomerId = "customer-67890";
    private const string TestDeliveryAddress = "123 Test Street, Test City, TC 12345";

    [TestInitialize]
    public void TestInitialize()
    {
        _logger = Substitute.For<ILogger<OrdersController>>();
        _orderService = Substitute.For<IOrderService>();
        _activitySource = new ActivitySource("Tests.OrdersController");

        _controller = new OrdersController(
            _logger,
            _orderService,
            _activitySource);
    }

    [TestCleanup]
    public void TestCleanup()
    {
        _activitySource.Dispose();
    }

    public void Dispose()
    {
        _activitySource?.Dispose();
    }

    #region Constructor Tests

    [TestMethod]
    public void Constructor_NullLogger_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrdersController(null!, _orderService, _activitySource));

        Assert.AreEqual("logger", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullOrderService_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrdersController(_logger, null!, _activitySource));

        Assert.AreEqual("orderService", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_NullActivitySource_ThrowsArgumentNullException()
    {
        // Arrange & Act & Assert
        var exception = Assert.ThrowsExactly<ArgumentNullException>(() =>
            new OrdersController(_logger, _orderService, null!));

        Assert.AreEqual("activitySource", exception.ParamName);
    }

    [TestMethod]
    public void Constructor_ValidParameters_CreatesInstance()
    {
        // Arrange & Act
        var controller = new OrdersController(_logger, _orderService, _activitySource);

        // Assert
        Assert.IsNotNull(controller);
    }

    #endregion

    #region PlaceOrder Tests

    [TestMethod]
    public async Task PlaceOrder_ValidOrder_ReturnsCreatedAtActionResult()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.PlaceOrderAsync(order, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(order));

        // Act
        var result = await _controller.PlaceOrder(order, CancellationToken.None);

        // Assert
        var actionResult = Assert.IsInstanceOfType<ActionResult<Order>>(result);
        var createdResult = Assert.IsInstanceOfType<CreatedAtActionResult>(actionResult.Result);
        Assert.AreEqual(StatusCodes.Status201Created, createdResult.StatusCode);
        Assert.AreEqual(nameof(OrdersController.GetOrderById), createdResult.ActionName);
    }

    [TestMethod]
    public async Task PlaceOrder_ValidOrder_ReturnsPlacedOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.PlaceOrderAsync(order, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(order));

        // Act
        var result = await _controller.PlaceOrder(order, CancellationToken.None);

        // Assert
        var createdResult = Assert.IsInstanceOfType<CreatedAtActionResult>(result.Result);
        var returnedOrder = Assert.IsInstanceOfType<Order>(createdResult.Value);
        Assert.AreEqual(order.Id, returnedOrder.Id);
    }

    [TestMethod]
    public async Task PlaceOrder_NullOrder_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.PlaceOrder(null, CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrder_InvalidOrderData_ReturnsBadRequest()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.PlaceOrderAsync(order, Arg.Any<CancellationToken>())
            .ThrowsAsync(new ArgumentException("Invalid order data"));

        // Act
        var result = await _controller.PlaceOrder(order, CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrder_OrderAlreadyExists_ReturnsConflict()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.PlaceOrderAsync(order, Arg.Any<CancellationToken>())
            .ThrowsAsync(new InvalidOperationException("Order already exists"));

        // Act
        var result = await _controller.PlaceOrder(order, CancellationToken.None);

        // Assert
        var conflictResult = Assert.IsInstanceOfType<ConflictObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status409Conflict, conflictResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrder_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.PlaceOrderAsync(order, Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Unexpected error"));

        // Act
        var result = await _controller.PlaceOrder(order, CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrder_CallsServiceWithCorrectOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.PlaceOrderAsync(order, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(order));

        // Act
        await _controller.PlaceOrder(order, CancellationToken.None);

        // Assert
        await _orderService.Received(1).PlaceOrderAsync(order, Arg.Any<CancellationToken>());
    }

    #endregion

    #region PlaceOrdersBatch Tests

    [TestMethod]
    public async Task PlaceOrdersBatch_ValidOrders_ReturnsOkResult()
    {
        // Arrange
        var orders = CreateTestOrders(3);
        _orderService.PlaceOrdersBatchAsync(Arg.Any<IEnumerable<Order>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(orders));

        // Act
        var result = await _controller.PlaceOrdersBatch(orders, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status200OK, okResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrdersBatch_ValidOrders_ReturnsPlacedOrders()
    {
        // Arrange
        var orders = CreateTestOrders(3);
        _orderService.PlaceOrdersBatchAsync(Arg.Any<IEnumerable<Order>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(orders));

        // Act
        var result = await _controller.PlaceOrdersBatch(orders, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        var returnedOrders = Assert.IsInstanceOfType<IEnumerable<Order>>(okResult.Value);
        Assert.AreEqual(3, returnedOrders.Count());
    }

    [TestMethod]
    public async Task PlaceOrdersBatch_NullOrders_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.PlaceOrdersBatch(null, CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrdersBatch_EmptyOrders_ReturnsBadRequest()
    {
        // Arrange
        var orders = new List<Order>();

        // Act
        var result = await _controller.PlaceOrdersBatch(orders, CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrdersBatch_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        var orders = CreateTestOrders(3);
        _orderService.PlaceOrdersBatchAsync(Arg.Any<IEnumerable<Order>>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Unexpected error"));

        // Act
        var result = await _controller.PlaceOrdersBatch(orders, CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    [TestMethod]
    public async Task PlaceOrdersBatch_SingleOrder_ReturnsOkResult()
    {
        // Arrange
        var orders = CreateTestOrders(1);
        _orderService.PlaceOrdersBatchAsync(Arg.Any<IEnumerable<Order>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(orders));

        // Act
        var result = await _controller.PlaceOrdersBatch(orders, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status200OK, okResult.StatusCode);
    }

    #endregion

    #region GetOrders Tests

    [TestMethod]
    public async Task GetOrders_OrdersExist_ReturnsOkResult()
    {
        // Arrange
        var orders = CreateTestOrders(5);
        _orderService.GetOrdersAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(orders));

        // Act
        var result = await _controller.GetOrders(CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status200OK, okResult.StatusCode);
    }

    [TestMethod]
    public async Task GetOrders_OrdersExist_ReturnsAllOrders()
    {
        // Arrange
        var orders = CreateTestOrders(5);
        _orderService.GetOrdersAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(orders));

        // Act
        var result = await _controller.GetOrders(CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        var returnedOrders = Assert.IsInstanceOfType<IEnumerable<Order>>(okResult.Value);
        Assert.AreEqual(5, returnedOrders.Count());
    }

    [TestMethod]
    public async Task GetOrders_NoOrders_ReturnsOkWithEmptyList()
    {
        // Arrange
        _orderService.GetOrdersAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<Order>>(new List<Order>()));

        // Act
        var result = await _controller.GetOrders(CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        var returnedOrders = Assert.IsInstanceOfType<IEnumerable<Order>>(okResult.Value);
        Assert.AreEqual(0, returnedOrders.Count());
    }

    [TestMethod]
    public async Task GetOrders_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        _orderService.GetOrdersAsync(Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.GetOrders(CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    #endregion

    #region GetOrderById Tests

    [TestMethod]
    public async Task GetOrderById_ExistingOrder_ReturnsOkResult()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));

        // Act
        var result = await _controller.GetOrderById(order.Id, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status200OK, okResult.StatusCode);
    }

    [TestMethod]
    public async Task GetOrderById_ExistingOrder_ReturnsOrder()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));

        // Act
        var result = await _controller.GetOrderById(order.Id, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        var returnedOrder = Assert.IsInstanceOfType<Order>(okResult.Value);
        Assert.AreEqual(order.Id, returnedOrder.Id);
    }

    [TestMethod]
    public async Task GetOrderById_NonExistingOrder_ReturnsNotFound()
    {
        // Arrange
        _orderService.GetOrderByIdAsync("non-existing", Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _controller.GetOrderById("non-existing", CancellationToken.None);

        // Assert
        var notFoundResult = Assert.IsInstanceOfType<NotFoundObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status404NotFound, notFoundResult.StatusCode);
    }

    [TestMethod]
    public async Task GetOrderById_EmptyId_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.GetOrderById("", CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task GetOrderById_WhitespaceId_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.GetOrderById("   ", CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task GetOrderById_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        _orderService.GetOrderByIdAsync(TestOrderId, Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.GetOrderById(TestOrderId, CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    #endregion

    #region DeleteOrder Tests

    [TestMethod]
    public async Task DeleteOrder_ExistingOrder_ReturnsNoContent()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderService.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(true));

        // Act
        var result = await _controller.DeleteOrder(order.Id, CancellationToken.None);

        // Assert
        var noContentResult = Assert.IsInstanceOfType<NoContentResult>(result);
        Assert.AreEqual(StatusCodes.Status204NoContent, noContentResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrder_NonExistingOrder_ReturnsNotFound()
    {
        // Arrange
        _orderService.GetOrderByIdAsync("non-existing", Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(null));

        // Act
        var result = await _controller.DeleteOrder("non-existing", CancellationToken.None);

        // Assert
        var notFoundResult = Assert.IsInstanceOfType<NotFoundObjectResult>(result);
        Assert.AreEqual(StatusCodes.Status404NotFound, notFoundResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrder_EmptyId_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.DeleteOrder("", CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrder_WhitespaceId_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.DeleteOrder("   ", CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrder_DeleteFails_ReturnsInternalServerError()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderService.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(false));

        // Act
        var result = await _controller.DeleteOrder(order.Id, CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrder_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderService.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.DeleteOrder(order.Id, CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrder_CallsServiceWithCorrectId()
    {
        // Arrange
        var order = CreateTestOrder();
        _orderService.GetOrderByIdAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<Order?>(order));
        _orderService.DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(true));

        // Act
        await _controller.DeleteOrder(order.Id, CancellationToken.None);

        // Assert
        await _orderService.Received(1).DeleteOrderAsync(order.Id, Arg.Any<CancellationToken>());
    }

    #endregion

    #region DeleteOrdersBatch Tests

    [TestMethod]
    public async Task DeleteOrdersBatch_ValidOrderIds_ReturnsOkResult()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };
        _orderService.DeleteOrdersBatchAsync(Arg.Any<IEnumerable<string>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(3));

        // Act
        var result = await _controller.DeleteOrdersBatch(orderIds, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status200OK, okResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrdersBatch_ValidOrderIds_ReturnsDeletedCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };
        _orderService.DeleteOrdersBatchAsync(Arg.Any<IEnumerable<string>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(3));

        // Act
        var result = await _controller.DeleteOrdersBatch(orderIds, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(3, okResult.Value);
    }

    [TestMethod]
    public async Task DeleteOrdersBatch_NullOrderIds_ReturnsBadRequest()
    {
        // Arrange & Act
        var result = await _controller.DeleteOrdersBatch(null, CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrdersBatch_EmptyOrderIds_ReturnsBadRequest()
    {
        // Arrange
        var orderIds = new List<string>();

        // Act
        var result = await _controller.DeleteOrdersBatch(orderIds, CancellationToken.None);

        // Assert
        var badRequestResult = Assert.IsInstanceOfType<BadRequestObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status400BadRequest, badRequestResult.StatusCode);
    }

    [TestMethod]
    public async Task DeleteOrdersBatch_PartialDeletion_ReturnsDeletedCount()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2", "order-3" };
        _orderService.DeleteOrdersBatchAsync(Arg.Any<IEnumerable<string>>(), Arg.Any<CancellationToken>())
            .Returns(Task.FromResult(2)); // Only 2 deleted

        // Act
        var result = await _controller.DeleteOrdersBatch(orderIds, CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(2, okResult.Value);
    }

    [TestMethod]
    public async Task DeleteOrdersBatch_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        var orderIds = new List<string> { "order-1", "order-2" };
        _orderService.DeleteOrdersBatchAsync(Arg.Any<IEnumerable<string>>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Database error"));

        // Act
        var result = await _controller.DeleteOrdersBatch(orderIds, CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    #endregion

    #region ListMessagesFromTopics Tests

    [TestMethod]
    public async Task ListMessagesFromTopics_MessagesExist_ReturnsOkResult()
    {
        // Arrange
        var messages = new List<object> { new { Id = "msg-1" }, new { Id = "msg-2" } };
        _orderService.ListMessagesFromTopicsAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<object>>(messages));

        // Act
        var result = await _controller.ListMessagesFromTopics(CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status200OK, okResult.StatusCode);
    }

    [TestMethod]
    public async Task ListMessagesFromTopics_MessagesExist_ReturnsMessages()
    {
        // Arrange
        var messages = new List<object> { new { Id = "msg-1" }, new { Id = "msg-2" } };
        _orderService.ListMessagesFromTopicsAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<object>>(messages));

        // Act
        var result = await _controller.ListMessagesFromTopics(CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        var returnedMessages = Assert.IsInstanceOfType<IEnumerable<object>>(okResult.Value);
        Assert.AreEqual(2, returnedMessages.Count());
    }

    [TestMethod]
    public async Task ListMessagesFromTopics_NoMessages_ReturnsOkWithEmptyList()
    {
        // Arrange
        _orderService.ListMessagesFromTopicsAsync(Arg.Any<CancellationToken>())
            .Returns(Task.FromResult<IEnumerable<object>>(new List<object>()));

        // Act
        var result = await _controller.ListMessagesFromTopics(CancellationToken.None);

        // Assert
        var okResult = Assert.IsInstanceOfType<OkObjectResult>(result.Result);
        var returnedMessages = Assert.IsInstanceOfType<IEnumerable<object>>(okResult.Value);
        Assert.AreEqual(0, returnedMessages.Count());
    }

    [TestMethod]
    public async Task ListMessagesFromTopics_UnexpectedException_ReturnsInternalServerError()
    {
        // Arrange
        _orderService.ListMessagesFromTopicsAsync(Arg.Any<CancellationToken>())
            .ThrowsAsync(new Exception("Service Bus error"));

        // Act
        var result = await _controller.ListMessagesFromTopics(CancellationToken.None);

        // Assert
        var objectResult = Assert.IsInstanceOfType<ObjectResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status500InternalServerError, objectResult.StatusCode);
    }

    #endregion

    #region ProcessOrder Tests

    [TestMethod]
    public async Task ProcessOrder_AnyOrder_ReturnsCreatedAtActionResult()
    {
        // Arrange
        var order = CreateTestOrder();

        // Act
        var result = await _controller.ProcessOrder(order, CancellationToken.None);

        // Assert
        var createdResult = Assert.IsInstanceOfType<CreatedAtActionResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status201Created, createdResult.StatusCode);
    }

    [TestMethod]
    public async Task ProcessOrder_NullOrder_ReturnsCreatedAtActionResult()
    {
        // Arrange & Act
        var result = await _controller.ProcessOrder(null, CancellationToken.None);

        // Assert
        var createdResult = Assert.IsInstanceOfType<CreatedAtActionResult>(result.Result);
        Assert.AreEqual(StatusCodes.Status201Created, createdResult.StatusCode);
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

    #endregion
}
