// =============================================================================
// Fluent Design System - UI Constants
// Centralized design tokens for consistent styling across the application
// =============================================================================

namespace eShop.Web.App.Shared;

/// <summary>
/// Provides centralized Fluent UI design tokens and constants for consistent styling across the application.
/// Contains spacing scales, typography, font weights, layout constraints, and grid templates.
/// </summary>
public static class FluentDesignSystem
{
    /// <summary>
    /// Defines spacing scale values in pixels for consistent margins and padding.
    /// </summary>
    public static class Spacing
    {
        /// <summary>Extra small spacing: 4px.</summary>
        public const string XSmall = "4";
        /// <summary>Small spacing: 8px.</summary>
        public const string Small = "8";
        /// <summary>Medium spacing: 12px.</summary>
        public const string Medium = "12";
        /// <summary>Large spacing: 16px.</summary>
        public const string Large = "16";
        /// <summary>Extra large spacing: 20px.</summary>
        public const string XLarge = "20";
        /// <summary>Double extra large spacing: 24px.</summary>
        public const string XXLarge = "24";
        /// <summary>Triple extra large spacing: 32px.</summary>
        public const string XXXLarge = "32";
    }

    /// <summary>
    /// Defines typography size values following Fluent UI design guidelines.
    /// </summary>
    public static class FontSizes
    {
        /// <summary>Caption font size: 11px.</summary>
        public const string Caption = "11px";
        /// <summary>Body font size: 13px.</summary>
        public const string Body = "13px";
        /// <summary>Large body font size: 14px.</summary>
        public const string BodyLarge = "14px";
        /// <summary>Subtitle font size: 15px.</summary>
        public const string Subtitle = "15px";
        /// <summary>Title font size: 16px.</summary>
        public const string Title = "16px";
        /// <summary>Large title font size: 18px.</summary>
        public const string LargeTitle = "18px";
    }

    /// <summary>
    /// Defines font weight values for text emphasis levels.
    /// </summary>
    public static class FontWeights
    {
        /// <summary>Regular font weight: 400.</summary>
        public const string Regular = "400";
        /// <summary>Semi-bold font weight: 600.</summary>
        public const string SemiBold = "600";
        /// <summary>Bold font weight: 700.</summary>
        public const string Bold = "700";
    }

    /// <summary>
    /// Defines maximum width constraints for responsive layouts.
    /// </summary>
    public static class MaxWidths
    {
        /// <summary>Small container max width: 800px.</summary>
        public const string Small = "800px";
        /// <summary>Medium container max width: 1000px.</summary>
        public const string Medium = "1000px";
        /// <summary>Large container max width: 1400px.</summary>
        public const string Large = "1400px";
    }

    /// <summary>
    /// Defines padding values for container elements.
    /// </summary>
    public static class Padding
    {
        /// <summary>Small padding: 16px.</summary>
        public const string Small = "16px";
        /// <summary>Medium padding: 20px.</summary>
        public const string Medium = "20px";
        /// <summary>Large padding: 24px.</summary>
        public const string Large = "24px";
    }

    /// <summary>
    /// Defines CSS grid column templates for data grids with harmonious proportions.
    /// </summary>
    public static class DataGridColumns
    {
        /// <summary>Column template for products grid: ID, Description, Quantity, Price, Total.</summary>
        public const string ProductsGrid = "100px 1fr 80px 120px 120px";
        /// <summary>Column template for orders header: Checkbox, ID, Date, Customer, Address, Total, Actions.</summary>
        public const string OrdersHeader = "20px 90px 110px 150px 1fr 100px 32px";
    }
}