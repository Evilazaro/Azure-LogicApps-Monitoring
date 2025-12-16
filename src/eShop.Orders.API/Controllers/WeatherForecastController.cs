// ------------------------------------------------------------------------------
// <copyright file="WeatherForecastController.cs" company="eShop Orders">
//     Copyright (c) eShop Orders. All rights reserved.
// </copyright>
// <summary>
//     Sample API controller for weather forecast demonstration.
// </summary>
// ------------------------------------------------------------------------------

using Microsoft.AspNetCore.Mvc;

namespace eShop.Orders.API.Controllers;

/// <summary>
/// API controller for weather forecast operations.
/// </summary>
/// <remarks>
/// This is a sample controller for demonstration purposes.
/// Remove or replace with actual business controllers in production.
/// </remarks>
[ApiController]
[Route("[controller]")]
public class WeatherForecastController : ControllerBase
{
    /// <summary>
    /// Predefined weather condition summaries.
    /// </summary>
    private static readonly string[] Summaries = new[]
    {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    private readonly ILogger<WeatherForecastController> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="WeatherForecastController"/> class.
    /// </summary>
    /// <param name="logger">Logger instance for diagnostics.</param>
    public WeatherForecastController(ILogger<WeatherForecastController> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Retrieves a 5-day weather forecast.
    /// </summary>
    /// <returns>A collection of weather forecasts for the next 5 days.</returns>
    /// <response code="200">Returns the weather forecast data.</response>
    [HttpGet(Name = "GetWeatherForecast")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public IEnumerable<WeatherForecast> Get()
    {
        // Generate 5 random weather forecasts for demonstration
        return Enumerable.Range(1, 5).Select(index => new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            TemperatureC = Random.Shared.Next(-20, 55),
            Summary = Summaries[Random.Shared.Next(Summaries.Length)]
        })
        .ToArray();
    }
}
