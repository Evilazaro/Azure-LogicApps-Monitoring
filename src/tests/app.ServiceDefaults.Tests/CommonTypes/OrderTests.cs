// =============================================================================
// Order Unit Tests
// Tests for the Order record including property validation and record behavior
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using System.ComponentModel.DataAnnotations;

namespace app.ServiceDefaults.Tests.CommonTypes;

[TestClass]
public sealed class OrderTests
{
    #region Test Helpers

    private static Order CreateValidOrder(
        string? id = null,
        string? customerId = null,
        string? deliveryAddress = null,
        decimal? total = null,
        List<OrderProduct>? products = null)
    {
        return new Order
        {
            Id = id ?? "ORD-001",
            CustomerId = customerId ?? "CUST-001",
            DeliveryAddress = deliveryAddress ?? "123 Main Street, City, Country",
            Total = total ?? 99.99m,
            Products = products ?? [CreateValidOrderProduct()]
        };
    }

    private static OrderProduct CreateValidOrderProduct(
        string? id = null,
        string? orderId = null,
        string? productId = null,
        string? description = null,
        int quantity = 1,
        decimal price = 19.99m)
    {
        return new OrderProduct
        {
            Id = id ?? "ORDPROD-001",
            OrderId = orderId ?? "ORD-001",
            ProductId = productId ?? "PROD-001",
            ProductDescription = description ?? "Test Product",
            Quantity = quantity,
            Price = price
        };
    }

    #endregion

    #region Constructor and Property Tests

    [TestMethod]
    public void Order_AllPropertiesSet_ReturnsCorrectValues()
    {
        // Arrange
        var expectedId = "ORD-123";
        var expectedCustomerId = "CUST-456";
        var expectedAddress = "456 Oak Avenue";
        var expectedTotal = 150.50m;
        var expectedProducts = new List<OrderProduct> { CreateValidOrderProduct() };
        var expectedDate = DateTime.UtcNow;

        // Act
        var order = new Order
        {
            Id = expectedId,
            CustomerId = expectedCustomerId,
            DeliveryAddress = expectedAddress,
            Total = expectedTotal,
            Products = expectedProducts,
            Date = expectedDate
        };

        // Assert
        Assert.AreEqual(expectedId, order.Id);
        Assert.AreEqual(expectedCustomerId, order.CustomerId);
        Assert.AreEqual(expectedAddress, order.DeliveryAddress);
        Assert.AreEqual(expectedTotal, order.Total);
        Assert.AreEqual(expectedProducts, order.Products);
        Assert.AreEqual(expectedDate, order.Date);
    }

    [TestMethod]
    public void Order_DateNotSpecified_DefaultsToUtcNow()
    {
        // Arrange
        var beforeCreation = DateTime.UtcNow;

        // Act
        var order = CreateValidOrder();
        var afterCreation = DateTime.UtcNow;

        // Assert
        Assert.IsTrue(order.Date >= beforeCreation && order.Date <= afterCreation,
            "Order Date should default to approximately DateTime.UtcNow");
    }

    #endregion

    #region Record Equality Tests

    [TestMethod]
    public void Order_SameValues_AreEqual()
    {
        // Arrange
        var products = new List<OrderProduct> { CreateValidOrderProduct() };
        var date = DateTime.UtcNow;
        var order1 = new Order
        {
            Id = "ORD-001",
            CustomerId = "CUST-001",
            DeliveryAddress = "123 Main St",
            Total = 100m,
            Products = products,
            Date = date
        };
        var order2 = new Order
        {
            Id = "ORD-001",
            CustomerId = "CUST-001",
            DeliveryAddress = "123 Main St",
            Total = 100m,
            Products = products,
            Date = date
        };

        // Act & Assert
        Assert.AreEqual(order1, order2);
    }

    [TestMethod]
    public void Order_DifferentId_AreNotEqual()
    {
        // Arrange
        var products = new List<OrderProduct> { CreateValidOrderProduct() };
        var date = DateTime.UtcNow;
        var order1 = new Order
        {
            Id = "ORD-001",
            CustomerId = "CUST-001",
            DeliveryAddress = "123 Main St",
            Total = 100m,
            Products = products,
            Date = date
        };
        var order2 = new Order
        {
            Id = "ORD-002",
            CustomerId = "CUST-001",
            DeliveryAddress = "123 Main St",
            Total = 100m,
            Products = products,
            Date = date
        };

        // Act & Assert
        Assert.AreNotEqual(order1, order2);
    }

    [TestMethod]
    public void Order_WithExpression_CreatesNewInstanceWithModifiedProperty()
    {
        // Arrange
        var original = CreateValidOrder(id: "ORD-001", total: 100m);

        // Act
        var modified = original with { Total = 200m };

        // Assert
        Assert.AreEqual("ORD-001", modified.Id);
        Assert.AreEqual(200m, modified.Total);
        Assert.AreNotSame(original, modified);
    }

    #endregion

    #region Id Validation Tests

    [TestMethod]
    public void Id_Required_ValidationFailsWhenEmpty()
    {
        // Note: Since Id is 'required', we test via validation attributes
        // We cannot create an Order with null Id due to 'required' keyword
        var order = CreateValidOrder(id: "");
        var context = new ValidationContext(order) { MemberName = nameof(Order.Id) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Id, context, results);

        // Assert
        Assert.IsFalse(isValid, "Empty Id should fail validation");
    }

    [TestMethod]
    [DataRow("A", true, "Minimum length (1 character)")]
    [DataRow("", false, "Empty string")]
    public void Id_StringLength_ValidationReturnsExpectedResult(string id, bool expectedValid, string scenario)
    {
        // Arrange
        var order = CreateValidOrder(id: string.IsNullOrEmpty(id) ? "temp" : id);
        if (!string.IsNullOrEmpty(id))
        {
            order = order with { Id = id };
        }
        else
        {
            order = order with { Id = "" };
        }
        var context = new ValidationContext(order) { MemberName = nameof(Order.Id) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Id, context, results);

        // Assert
        Assert.AreEqual(expectedValid, isValid, $"Validation failed for scenario: {scenario}");
    }

    [TestMethod]
    public void Id_ExceedsMaxLength_ValidationFails()
    {
        // Arrange
        var order = CreateValidOrder(id: new string('A', 101));
        var context = new ValidationContext(order) { MemberName = nameof(Order.Id) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Id, context, results);

        // Assert
        Assert.IsFalse(isValid, "Id exceeding 100 characters should fail validation");
    }

    #endregion

    #region CustomerId Validation Tests

    [TestMethod]
    public void CustomerId_ExceedsMaxLength_ValidationFails()
    {
        // Arrange
        var order = CreateValidOrder(customerId: new string('B', 101));
        var context = new ValidationContext(order) { MemberName = nameof(Order.CustomerId) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.CustomerId, context, results);

        // Assert
        Assert.IsFalse(isValid, "CustomerId exceeding 100 characters should fail validation");
    }

    [TestMethod]
    public void CustomerId_ValidLength_ValidationPasses()
    {
        // Arrange
        var order = CreateValidOrder(customerId: "CUST-12345");
        var context = new ValidationContext(order) { MemberName = nameof(Order.CustomerId) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.CustomerId, context, results);

        // Assert
        Assert.IsTrue(isValid);
    }

    #endregion

    #region DeliveryAddress Validation Tests

    [TestMethod]
    public void DeliveryAddress_BelowMinLength_ValidationFails()
    {
        // Arrange
        var order = CreateValidOrder(deliveryAddress: "1234"); // 4 chars, min is 5
        var context = new ValidationContext(order) { MemberName = nameof(Order.DeliveryAddress) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.DeliveryAddress, context, results);

        // Assert
        Assert.IsFalse(isValid, "DeliveryAddress below 5 characters should fail validation");
    }

    [TestMethod]
    public void DeliveryAddress_ExceedsMaxLength_ValidationFails()
    {
        // Arrange
        var order = CreateValidOrder(deliveryAddress: new string('X', 501));
        var context = new ValidationContext(order) { MemberName = nameof(Order.DeliveryAddress) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.DeliveryAddress, context, results);

        // Assert
        Assert.IsFalse(isValid, "DeliveryAddress exceeding 500 characters should fail validation");
    }

    [TestMethod]
    public void DeliveryAddress_AtMinLength_ValidationPasses()
    {
        // Arrange
        var order = CreateValidOrder(deliveryAddress: "12345"); // Exactly 5 chars
        var context = new ValidationContext(order) { MemberName = nameof(Order.DeliveryAddress) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.DeliveryAddress, context, results);

        // Assert
        Assert.IsTrue(isValid, "DeliveryAddress at exactly 5 characters should pass validation");
    }

    #endregion

    #region Total Validation Tests

    [TestMethod]
    [DataRow(0.01, true, "Minimum valid total")]
    [DataRow(0.00, false, "Zero total")]
    [DataRow(-1.00, false, "Negative total")]
    [DataRow(999999.99, true, "Large valid total")]
    public void Total_RangeValidation_ReturnsExpectedResult(double total, bool expectedValid, string scenario)
    {
        // Arrange
        var order = CreateValidOrder(total: (decimal)total);
        var context = new ValidationContext(order) { MemberName = nameof(Order.Total) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Total, context, results);

        // Assert
        Assert.AreEqual(expectedValid, isValid, $"Validation failed for scenario: {scenario}");
    }

    #endregion

    #region Products Validation Tests

    [TestMethod]
    public void Products_EmptyList_ValidationFails()
    {
        // Arrange
        var order = CreateValidOrder(products: []);
        var context = new ValidationContext(order) { MemberName = nameof(Order.Products) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Products, context, results);

        // Assert
        Assert.IsFalse(isValid, "Empty products list should fail validation");
    }

    [TestMethod]
    public void Products_SingleProduct_ValidationPasses()
    {
        // Arrange
        var order = CreateValidOrder(products: [CreateValidOrderProduct()]);
        var context = new ValidationContext(order) { MemberName = nameof(Order.Products) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Products, context, results);

        // Assert
        Assert.IsTrue(isValid);
    }

    [TestMethod]
    public void Products_MultipleProducts_ValidationPasses()
    {
        // Arrange
        var products = new List<OrderProduct>
        {
            CreateValidOrderProduct(id: "P1"),
            CreateValidOrderProduct(id: "P2"),
            CreateValidOrderProduct(id: "P3")
        };
        var order = CreateValidOrder(products: products);
        var context = new ValidationContext(order) { MemberName = nameof(Order.Products) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(order.Products, context, results);

        // Assert
        Assert.IsTrue(isValid);
    }

    #endregion

    #region Full Object Validation Tests

    [TestMethod]
    public void FullObject_AllValidProperties_ValidationPasses()
    {
        // Arrange
        var order = CreateValidOrder();
        var context = new ValidationContext(order);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(order, context, results, validateAllProperties: true);

        // Assert
        Assert.IsTrue(isValid, "Valid order should pass full validation");
    }

    [TestMethod]
    public void FullObject_MultipleInvalidProperties_ReturnsAllErrors()
    {
        // Arrange
        var order = new Order
        {
            Id = "", // Invalid: empty
            CustomerId = "", // Invalid: empty
            DeliveryAddress = "123", // Invalid: too short
            Total = 0m, // Invalid: must be > 0
            Products = [] // Invalid: empty
        };
        var context = new ValidationContext(order);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(order, context, results, validateAllProperties: true);

        // Assert
        Assert.IsFalse(isValid, "Order with multiple invalid properties should fail validation");
        Assert.IsNotEmpty(results, "Should have validation errors");
    }

    #endregion
}
