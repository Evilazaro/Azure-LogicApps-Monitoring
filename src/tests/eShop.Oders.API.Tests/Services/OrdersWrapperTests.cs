// =============================================================================
// Unit Tests for OrdersWrapper
// Tests the wrapper class for order collections
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Services;

namespace eShop.Orders.API.Tests.Services;

[TestClass]
public sealed class OrdersWrapperTests
{
    #region Constructor and Initialization Tests

    [TestMethod]
    public void OrdersWrapper_WithEmptyOrders_CreatesInstanceWithEmptyList()
    {
        // Arrange & Act
        var wrapper = new OrdersWrapper
        {
            Orders = []
        };

        // Assert
        Assert.IsNotNull(wrapper);
        Assert.IsNotNull(wrapper.Orders);
        Assert.AreEqual(0, wrapper.Orders.Count);
    }

    [TestMethod]
    public void OrdersWrapper_WithOrders_CreatesInstanceWithOrdersList()
    {
        // Arrange
        var orders = new List<Order>
        {
            CreateTestOrder("order-1", "customer-1"),
            CreateTestOrder("order-2", "customer-2")
        };

        // Act
        var wrapper = new OrdersWrapper
        {
            Orders = orders
        };

        // Assert
        Assert.IsNotNull(wrapper);
        Assert.AreEqual(2, wrapper.Orders.Count);
    }

    [TestMethod]
    public void OrdersWrapper_WithSingleOrder_CreatesInstanceWithSingleOrderList()
    {
        // Arrange
        var order = CreateTestOrder("order-1", "customer-1");

        // Act
        var wrapper = new OrdersWrapper
        {
            Orders = [order]
        };

        // Assert
        Assert.IsNotNull(wrapper);
        Assert.AreEqual(1, wrapper.Orders.Count);
        Assert.AreEqual("order-1", wrapper.Orders[0].Id);
    }

    #endregion

    #region Orders Property Tests

    [TestMethod]
    public void Orders_CanBeModified_AfterInitialization()
    {
        // Arrange
        var wrapper = new OrdersWrapper
        {
            Orders = []
        };

        var newOrder = CreateTestOrder("order-1", "customer-1");

        // Act
        wrapper.Orders.Add(newOrder);

        // Assert
        Assert.AreEqual(1, wrapper.Orders.Count);
        Assert.AreEqual("order-1", wrapper.Orders[0].Id);
    }

    [TestMethod]
    public void Orders_CanBeCleared_AfterInitialization()
    {
        // Arrange
        var wrapper = new OrdersWrapper
        {
            Orders =
            [
                CreateTestOrder("order-1", "customer-1"),
                CreateTestOrder("order-2", "customer-2")
            ]
        };

        // Act
        wrapper.Orders.Clear();

        // Assert
        Assert.AreEqual(0, wrapper.Orders.Count);
    }

    [TestMethod]
    public void Orders_ContainsCorrectOrderData()
    {
        // Arrange
        var order = CreateTestOrder("test-order", "test-customer");

        // Act
        var wrapper = new OrdersWrapper
        {
            Orders = [order]
        };

        // Assert
        var retrievedOrder = wrapper.Orders[0];
        Assert.AreEqual("test-order", retrievedOrder.Id);
        Assert.AreEqual("test-customer", retrievedOrder.CustomerId);
        Assert.AreEqual("123 Test Street, Test City, TC 12345", retrievedOrder.DeliveryAddress);
        Assert.AreEqual(99.99m, retrievedOrder.Total);
        Assert.AreEqual(1, retrievedOrder.Products.Count);
    }

    [TestMethod]
    public void Orders_CanRemoveOrder_AfterInitialization()
    {
        // Arrange
        var order1 = CreateTestOrder("order-1", "customer-1");
        var order2 = CreateTestOrder("order-2", "customer-2");

        var wrapper = new OrdersWrapper
        {
            Orders = [order1, order2]
        };

        // Act
        wrapper.Orders.Remove(order1);

        // Assert
        Assert.AreEqual(1, wrapper.Orders.Count);
        Assert.AreEqual("order-2", wrapper.Orders[0].Id);
    }

    #endregion

    #region Multiple Orders Tests

    [TestMethod]
    public void OrdersWrapper_WithMultipleOrders_MaintainsOrderSequence()
    {
        // Arrange
        var orders = Enumerable.Range(1, 5)
            .Select(i => CreateTestOrder($"order-{i}", $"customer-{i}"))
            .ToList();

        // Act
        var wrapper = new OrdersWrapper
        {
            Orders = orders
        };

        // Assert
        Assert.AreEqual(5, wrapper.Orders.Count);
        for (int i = 0; i < 5; i++)
        {
            Assert.AreEqual($"order-{i + 1}", wrapper.Orders[i].Id);
            Assert.AreEqual($"customer-{i + 1}", wrapper.Orders[i].CustomerId);
        }
    }

    [TestMethod]
    public void OrdersWrapper_CanFilterOrders_UsingLinq()
    {
        // Arrange
        var wrapper = new OrdersWrapper
        {
            Orders =
            [
                CreateTestOrderWithTotal("order-1", "customer-1", 50.00m),
                CreateTestOrderWithTotal("order-2", "customer-2", 150.00m),
                CreateTestOrderWithTotal("order-3", "customer-3", 75.00m)
            ]
        };

        // Act
        var highValueOrders = wrapper.Orders.Where(o => o.Total > 100.00m).ToList();

        // Assert
        Assert.AreEqual(1, highValueOrders.Count);
        Assert.AreEqual("order-2", highValueOrders[0].Id);
    }

    [TestMethod]
    public void OrdersWrapper_CanCalculateTotalSum_UsingLinq()
    {
        // Arrange
        var wrapper = new OrdersWrapper
        {
            Orders =
            [
                CreateTestOrderWithTotal("order-1", "customer-1", 50.00m),
                CreateTestOrderWithTotal("order-2", "customer-2", 100.00m),
                CreateTestOrderWithTotal("order-3", "customer-3", 75.00m)
            ]
        };

        // Act
        var totalSum = wrapper.Orders.Sum(o => o.Total);

        // Assert
        Assert.AreEqual(225.00m, totalSum);
    }

    #endregion

    #region Helper Methods

    private static Order CreateTestOrder(string orderId, string customerId)
    {
        return new Order
        {
            Id = orderId,
            CustomerId = customerId,
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = 99.99m,
            Products =
            [
                new OrderProduct
                {
                    Id = $"{orderId}-product-1",
                    OrderId = orderId,
                    ProductId = "product-1",
                    ProductDescription = "Test Product 1",
                    Quantity = 1,
                    Price = 99.99m
                }
            ]
        };
    }

    private static Order CreateTestOrderWithTotal(string orderId, string customerId, decimal total)
    {
        return new Order
        {
            Id = orderId,
            CustomerId = customerId,
            Date = DateTime.UtcNow,
            DeliveryAddress = "123 Test Street, Test City, TC 12345",
            Total = total,
            Products =
            [
                new OrderProduct
                {
                    Id = $"{orderId}-product-1",
                    OrderId = orderId,
                    ProductId = "product-1",
                    ProductDescription = "Test Product 1",
                    Quantity = 1,
                    Price = total
                }
            ]
        };
    }

    #endregion
}