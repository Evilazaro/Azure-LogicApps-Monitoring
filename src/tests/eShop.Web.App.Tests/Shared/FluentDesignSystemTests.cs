// =============================================================================
// FluentDesignSystem Unit Tests
// Tests for the design system constants and configuration
// =============================================================================

using eShop.Web.App.Shared;

namespace eShop.Web.App.Tests.Shared;

[TestClass]
public sealed class FluentDesignSystemTests
{
    #region Spacing Tests

    [TestMethod]
    public void Spacing_XSmall_HasExpectedValue()
    {
        Assert.AreEqual("4", FluentDesignSystem.Spacing.XSmall);
    }

    [TestMethod]
    public void Spacing_Small_HasExpectedValue()
    {
        Assert.AreEqual("8", FluentDesignSystem.Spacing.Small);
    }

    [TestMethod]
    public void Spacing_Medium_HasExpectedValue()
    {
        Assert.AreEqual("12", FluentDesignSystem.Spacing.Medium);
    }

    [TestMethod]
    public void Spacing_Large_HasExpectedValue()
    {
        Assert.AreEqual("16", FluentDesignSystem.Spacing.Large);
    }

    [TestMethod]
    public void Spacing_XLarge_HasExpectedValue()
    {
        Assert.AreEqual("20", FluentDesignSystem.Spacing.XLarge);
    }

    [TestMethod]
    public void Spacing_XXLarge_HasExpectedValue()
    {
        Assert.AreEqual("24", FluentDesignSystem.Spacing.XXLarge);
    }

    [TestMethod]
    public void Spacing_XXXLarge_HasExpectedValue()
    {
        Assert.AreEqual("32", FluentDesignSystem.Spacing.XXXLarge);
    }

    [TestMethod]
    public void Spacing_ValuesAreInAscendingOrder()
    {
        // Arrange
        var spacingValues = new[]
        {
            int.Parse(FluentDesignSystem.Spacing.XSmall),
            int.Parse(FluentDesignSystem.Spacing.Small),
            int.Parse(FluentDesignSystem.Spacing.Medium),
            int.Parse(FluentDesignSystem.Spacing.Large),
            int.Parse(FluentDesignSystem.Spacing.XLarge),
            int.Parse(FluentDesignSystem.Spacing.XXLarge),
            int.Parse(FluentDesignSystem.Spacing.XXXLarge)
        };

        // Act & Assert
        for (int i = 1; i < spacingValues.Length; i++)
        {
            Assert.IsTrue(spacingValues[i] > spacingValues[i - 1],
                $"Spacing value at index {i} ({spacingValues[i]}) should be greater than {spacingValues[i - 1]}");
        }
    }

    #endregion

    #region FontSizes Tests

    [TestMethod]
    public void FontSizes_Caption_HasExpectedValue()
    {
        Assert.AreEqual("11px", FluentDesignSystem.FontSizes.Caption);
    }

    [TestMethod]
    public void FontSizes_Body_HasExpectedValue()
    {
        Assert.AreEqual("13px", FluentDesignSystem.FontSizes.Body);
    }

    [TestMethod]
    public void FontSizes_BodyLarge_HasExpectedValue()
    {
        Assert.AreEqual("14px", FluentDesignSystem.FontSizes.BodyLarge);
    }

    [TestMethod]
    public void FontSizes_Subtitle_HasExpectedValue()
    {
        Assert.AreEqual("15px", FluentDesignSystem.FontSizes.Subtitle);
    }

    [TestMethod]
    public void FontSizes_Title_HasExpectedValue()
    {
        Assert.AreEqual("16px", FluentDesignSystem.FontSizes.Title);
    }

    [TestMethod]
    public void FontSizes_LargeTitle_HasExpectedValue()
    {
        Assert.AreEqual("18px", FluentDesignSystem.FontSizes.LargeTitle);
    }

    [TestMethod]
    public void FontSizes_AllValuesEndWithPx()
    {
        // Arrange
        var fontSizes = new[]
        {
            FluentDesignSystem.FontSizes.Caption,
            FluentDesignSystem.FontSizes.Body,
            FluentDesignSystem.FontSizes.BodyLarge,
            FluentDesignSystem.FontSizes.Subtitle,
            FluentDesignSystem.FontSizes.Title,
            FluentDesignSystem.FontSizes.LargeTitle
        };

        // Act & Assert
        foreach (var fontSize in fontSizes)
        {
            Assert.IsTrue(fontSize.EndsWith("px", StringComparison.Ordinal),
                $"Font size '{fontSize}' should end with 'px'");
        }
    }

    #endregion

    #region FontWeights Tests

    [TestMethod]
    public void FontWeights_Regular_HasExpectedValue()
    {
        Assert.AreEqual("400", FluentDesignSystem.FontWeights.Regular);
    }

    [TestMethod]
    public void FontWeights_SemiBold_HasExpectedValue()
    {
        Assert.AreEqual("600", FluentDesignSystem.FontWeights.SemiBold);
    }

    [TestMethod]
    public void FontWeights_Bold_HasExpectedValue()
    {
        Assert.AreEqual("700", FluentDesignSystem.FontWeights.Bold);
    }

    [TestMethod]
    public void FontWeights_ValuesAreValidCssFontWeights()
    {
        // Arrange
        var fontWeights = new[]
        {
            FluentDesignSystem.FontWeights.Regular,
            FluentDesignSystem.FontWeights.SemiBold,
            FluentDesignSystem.FontWeights.Bold
        };

        // Act & Assert
        foreach (var weight in fontWeights)
        {
            Assert.IsTrue(int.TryParse(weight, out int parsedWeight),
                $"Font weight '{weight}' should be a valid integer");
            Assert.IsTrue(parsedWeight >= 100 && parsedWeight <= 900,
                $"Font weight {parsedWeight} should be between 100 and 900");
            Assert.IsTrue(parsedWeight % 100 == 0,
                $"Font weight {parsedWeight} should be a multiple of 100");
        }
    }

    #endregion

    #region MaxWidths Tests

    [TestMethod]
    public void MaxWidths_Small_HasExpectedValue()
    {
        Assert.AreEqual("800px", FluentDesignSystem.MaxWidths.Small);
    }

    [TestMethod]
    public void MaxWidths_Medium_HasExpectedValue()
    {
        Assert.AreEqual("1000px", FluentDesignSystem.MaxWidths.Medium);
    }

    [TestMethod]
    public void MaxWidths_Large_HasExpectedValue()
    {
        Assert.AreEqual("1400px", FluentDesignSystem.MaxWidths.Large);
    }

    [TestMethod]
    public void MaxWidths_AllValuesEndWithPx()
    {
        // Arrange
        var maxWidths = new[]
        {
            FluentDesignSystem.MaxWidths.Small,
            FluentDesignSystem.MaxWidths.Medium,
            FluentDesignSystem.MaxWidths.Large
        };

        // Act & Assert
        foreach (var width in maxWidths)
        {
            Assert.IsTrue(width.EndsWith("px", StringComparison.Ordinal),
                $"Max width '{width}' should end with 'px'");
        }
    }

    #endregion

    #region Padding Tests

    [TestMethod]
    public void Padding_Small_HasExpectedValue()
    {
        Assert.AreEqual("16px", FluentDesignSystem.Padding.Small);
    }

    [TestMethod]
    public void Padding_Medium_HasExpectedValue()
    {
        Assert.AreEqual("20px", FluentDesignSystem.Padding.Medium);
    }

    [TestMethod]
    public void Padding_Large_HasExpectedValue()
    {
        Assert.AreEqual("24px", FluentDesignSystem.Padding.Large);
    }

    [TestMethod]
    public void Padding_AllValuesEndWithPx()
    {
        // Arrange
        var paddingValues = new[]
        {
            FluentDesignSystem.Padding.Small,
            FluentDesignSystem.Padding.Medium,
            FluentDesignSystem.Padding.Large
        };

        // Act & Assert
        foreach (var padding in paddingValues)
        {
            Assert.IsTrue(padding.EndsWith("px", StringComparison.Ordinal),
                $"Padding '{padding}' should end with 'px'");
        }
    }

    #endregion

    #region DataGridColumns Tests

    [TestMethod]
    public void DataGridColumns_ProductsGrid_HasExpectedValue()
    {
        Assert.AreEqual("100px 1fr 80px 120px 120px", FluentDesignSystem.DataGridColumns.ProductsGrid);
    }

    [TestMethod]
    public void DataGridColumns_OrdersHeader_HasExpectedValue()
    {
        Assert.AreEqual("20px 90px 110px 150px 1fr 100px 32px", FluentDesignSystem.DataGridColumns.OrdersHeader);
    }

    [TestMethod]
    public void DataGridColumns_ProductsGrid_HasCorrectColumnCount()
    {
        // Arrange
        var columns = FluentDesignSystem.DataGridColumns.ProductsGrid.Split(' ');

        // Assert
        Assert.AreEqual(5, columns.Length, "ProductsGrid should have 5 columns");
    }

    [TestMethod]
    public void DataGridColumns_OrdersHeader_HasCorrectColumnCount()
    {
        // Arrange
        var columns = FluentDesignSystem.DataGridColumns.OrdersHeader.Split(' ');

        // Assert
        Assert.AreEqual(7, columns.Length, "OrdersHeader should have 7 columns");
    }

    #endregion
}
