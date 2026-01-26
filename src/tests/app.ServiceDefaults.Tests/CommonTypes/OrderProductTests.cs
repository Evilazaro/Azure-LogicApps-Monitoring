// =============================================================================
// OrderProduct Unit Tests
// Tests for the OrderProduct record including property validation and record behavior
// =============================================================================

using System.ComponentModel.DataAnnotations;
using app.ServiceDefaults.CommonTypes;

namespace app.ServiceDefaults.Tests.CommonTypes;

[TestClass]
public sealed class OrderProductTests
{
    #region Test Helpers

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
            ProductDescription = description ?? "Test Product Description",
            Quantity = quantity,
            Price = price
        };
    }

    #endregion

    #region Constructor and Property Tests

    [TestMethod]
    public void OrderProduct_AllPropertiesSet_ReturnsCorrectValues()
    {
        // Arrange
        var expectedId = "ORDPROD-123";
        var expectedOrderId = "ORD-456";
        var expectedProductId = "PROD-789";
        var expectedDescription = "Premium Widget";
        var expectedQuantity = 5;
        var expectedPrice = 49.99m;

        // Act
        var orderProduct = new OrderProduct
        {
            Id = expectedId,
            OrderId = expectedOrderId,
            ProductId = expectedProductId,
            ProductDescription = expectedDescription,
            Quantity = expectedQuantity,
            Price = expectedPrice
        };

        // Assert
        Assert.AreEqual(expectedId, orderProduct.Id);
        Assert.AreEqual(expectedOrderId, orderProduct.OrderId);
        Assert.AreEqual(expectedProductId, orderProduct.ProductId);
        Assert.AreEqual(expectedDescription, orderProduct.ProductDescription);
        Assert.AreEqual(expectedQuantity, orderProduct.Quantity);
        Assert.AreEqual(expectedPrice, orderProduct.Price);
    }

    [TestMethod]
    public void OrderProduct_DefaultQuantity_IsZero()
    {
        // Arrange & Act
        var orderProduct = new OrderProduct
        {
            Id = "OP-001",
            OrderId = "ORD-001",
            ProductId = "PROD-001",
            ProductDescription = "Test"
        };

        // Assert
        Assert.AreEqual(0, orderProduct.Quantity);
    }

    [TestMethod]
    public void OrderProduct_DefaultPrice_IsZero()
    {
        // Arrange & Act
        var orderProduct = new OrderProduct
        {
            Id = "OP-001",
            OrderId = "ORD-001",
            ProductId = "PROD-001",
            ProductDescription = "Test"
        };

        // Assert
        Assert.AreEqual(0m, orderProduct.Price);
    }

    #endregion

    #region Record Equality Tests

    [TestMethod]
    public void OrderProduct_SameValues_AreEqual()
    {
        // Arrange
        var product1 = CreateValidOrderProduct(
            id: "OP-001",
            orderId: "ORD-001",
            productId: "PROD-001",
            description: "Widget",
            quantity: 2,
            price: 25.00m
        );
        var product2 = CreateValidOrderProduct(
            id: "OP-001",
            orderId: "ORD-001",
            productId: "PROD-001",
            description: "Widget",
            quantity: 2,
            price: 25.00m
        );

        // Act & Assert
        Assert.AreEqual(product1, product2);
    }

    [TestMethod]
    public void OrderProduct_DifferentQuantity_AreNotEqual()
    {
        // Arrange
        var product1 = CreateValidOrderProduct(quantity: 1);
        var product2 = CreateValidOrderProduct(quantity: 2);

        // Act & Assert
        Assert.AreNotEqual(product1, product2);
    }

    [TestMethod]
    public void OrderProduct_DifferentPrice_AreNotEqual()
    {
        // Arrange
        var product1 = CreateValidOrderProduct(price: 10.00m);
        var product2 = CreateValidOrderProduct(price: 20.00m);

        // Act & Assert
        Assert.AreNotEqual(product1, product2);
    }

    [TestMethod]
    public void OrderProduct_WithExpression_CreatesModifiedCopy()
    {
        // Arrange
        var original = CreateValidOrderProduct(quantity: 1, price: 10.00m);

        // Act
        var modified = original with { Quantity = 5, Price = 8.00m };

        // Assert
        Assert.AreEqual(5, modified.Quantity);
        Assert.AreEqual(8.00m, modified.Price);
        Assert.AreEqual(original.Id, modified.Id);
        Assert.AreNotSame(original, modified);
    }

    #endregion

    #region ProductDescription Validation Tests

    [TestMethod]
    public void ProductDescription_EmptyString_ValidationFails()
    {
        // Arrange
        var product = CreateValidOrderProduct(description: "");
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.ProductDescription) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.ProductDescription, context, results);

        // Assert
        Assert.IsFalse(isValid, "Empty description should fail validation");
    }

    [TestMethod]
    public void ProductDescription_ExceedsMaxLength_ValidationFails()
    {
        // Arrange
        var product = CreateValidOrderProduct(description: new string('X', 501));
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.ProductDescription) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.ProductDescription, context, results);

        // Assert
        Assert.IsFalse(isValid, "Description exceeding 500 characters should fail validation");
    }

    [TestMethod]
    public void ProductDescription_AtMinLength_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(description: "A"); // Exactly 1 char
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.ProductDescription) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.ProductDescription, context, results);

        // Assert
        Assert.IsTrue(isValid, "Description at exactly 1 character should pass validation");
    }

    [TestMethod]
    public void ProductDescription_AtMaxLength_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(description: new string('X', 500));
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.ProductDescription) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.ProductDescription, context, results);

        // Assert
        Assert.IsTrue(isValid, "Description at exactly 500 characters should pass validation");
    }

    #endregion

    #region Quantity Validation Tests

    [TestMethod]
    [DataRow(1, true, "Minimum valid quantity")]
    [DataRow(0, false, "Zero quantity")]
    [DataRow(-1, false, "Negative quantity")]
    [DataRow(100, true, "Large quantity")]
    [DataRow(int.MaxValue, true, "Max int quantity")]
    public void Quantity_RangeValidation_ReturnsExpectedResult(int quantity, bool expectedValid, string scenario)
    {
        // Arrange
        var product = CreateValidOrderProduct(quantity: quantity);
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.Quantity) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.Quantity, context, results);

        // Assert
        Assert.AreEqual(expectedValid, isValid, $"Validation failed for scenario: {scenario}");
    }

    #endregion

    #region Price Validation Tests

    [TestMethod]
    [DataRow(0.01, true, "Minimum valid price")]
    [DataRow(0.00, false, "Zero price")]
    [DataRow(-0.01, false, "Negative price")]
    [DataRow(9999.99, true, "Large price")]
    public void Price_RangeValidation_ReturnsExpectedResult(double price, bool expectedValid, string scenario)
    {
        // Arrange
        var product = CreateValidOrderProduct(price: (decimal)price);
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.Price) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.Price, context, results);

        // Assert
        Assert.AreEqual(expectedValid, isValid, $"Validation failed for scenario: {scenario}");
    }

    #endregion

    #region Full Object Validation Tests

    [TestMethod]
    public void FullObject_AllValidProperties_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(quantity: 2, price: 15.99m);
        var context = new ValidationContext(product);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(product, context, results, validateAllProperties: true);

        // Assert
        Assert.IsTrue(isValid, "Valid order product should pass full validation");
    }

    [TestMethod]
    public void FullObject_InvalidQuantityAndPrice_FailsValidation()
    {
        // Arrange
        var product = new OrderProduct
        {
            Id = "OP-001",
            OrderId = "ORD-001",
            ProductId = "PROD-001",
            ProductDescription = "Test Product",
            Quantity = 0, // Invalid
            Price = 0m   // Invalid
        };
        var context = new ValidationContext(product);
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateObject(product, context, results, validateAllProperties: true);

        // Assert
        Assert.IsFalse(isValid, "Product with invalid quantity and price should fail validation");
        Assert.IsTrue(results.Count >= 2, "Should have at least 2 validation errors");
    }

    #endregion

    #region Edge Cases

    [TestMethod]
    public void Price_VerySmallDecimal_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(price: 0.01m);
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.Price) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.Price, context, results);

        // Assert
        Assert.IsTrue(isValid, "Price of $0.01 should be valid");
    }

    [TestMethod]
    public void Quantity_MaxInt_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(quantity: int.MaxValue);
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.Quantity) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.Quantity, context, results);

        // Assert
        Assert.IsTrue(isValid, "Maximum int quantity should be valid");
    }

    [TestMethod]
    public void ProductDescription_ContainsSpecialCharacters_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(description: "Widget™ - 50% off! (Limited Edition) & More");
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.ProductDescription) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.ProductDescription, context, results);

        // Assert
        Assert.IsTrue(isValid, "Description with special characters should be valid");
    }

    [TestMethod]
    public void ProductDescription_ContainsUnicode_ValidationPasses()
    {
        // Arrange
        var product = CreateValidOrderProduct(description: "ウィジェット日本語製品 🎉");
        var context = new ValidationContext(product) { MemberName = nameof(OrderProduct.ProductDescription) };
        var results = new List<ValidationResult>();

        // Act
        var isValid = Validator.TryValidateProperty(product.ProductDescription, context, results);

        // Assert
        Assert.IsTrue(isValid, "Description with Unicode characters should be valid");
    }

    #endregion
}
