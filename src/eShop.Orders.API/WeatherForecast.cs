// ------------------------------------------------------------------------------
// <copyright file="WeatherForecast.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// ------------------------------------------------------------------------------

namespace eShop.Orders.API;

/// <summary>
/// Represents a weather forecast for a specific date.
/// </summary>
/// <remarks>
/// This is a sample model used for demonstration purposes.
/// In production, this would be replaced with actual weather data models.
/// </remarks>
public class WeatherForecast
{
    /// <summary>
    /// Gets or sets the date of the weather forecast.
    /// </summary>
    public DateOnly Date { get; set; }

    /// <summary>
    /// Gets or sets the temperature in Celsius.
    /// </summary>
    public int TemperatureC { get; set; }

    /// <summary>
    /// Gets the temperature in Fahrenheit.
    /// Calculated from Celsius using the formula: F = 32 + (C / 0.5556)
    /// </summary>
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);

    /// <summary>
    /// Gets or sets the weather summary description.
    /// </summary>
    /// <example>"Freezing", "Mild", "Hot"</example>
    public string? Summary { get; set; }
}
