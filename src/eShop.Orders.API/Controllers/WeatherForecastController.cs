// =============================================================================
// Weather Forecast Controller - Demo API
// Sample API endpoint for demonstration and health check purposes
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using Microsoft.AspNetCore.Mvc;

namespace eShop.Orders.API.Controllers;

/// <summary>
/// API controller that provides weather forecast data for demonstration purposes.
/// This controller serves as a sample endpoint and can be used for health checks.
/// </summary>
[ApiController]
[Route("[controller]")]
public class WeatherForecastController : ControllerBase
{
    /// <summary>
    /// Predefined weather condition summaries for random forecast generation.
    /// </summary>
    private static readonly string[] Summaries = new[]
    {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    private readonly ILogger<WeatherForecastController> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="WeatherForecastController"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    public WeatherForecastController(ILogger<WeatherForecastController> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Gets a collection of weather forecasts for the next 5 days.
    /// </summary>
    /// <returns>A collection of <see cref="WeatherForecast"/> objects with random temperature and summary data.</returns>
    /// <response code="200">Returns a collection of 5 weather forecasts.</response>
    [HttpGet(Name = "GetWeatherForecast")]
    [ProducesResponseType(typeof(IEnumerable<WeatherForecast>), StatusCodes.Status200OK)]
    public IEnumerable<WeatherForecast> Get()
    {
        return Enumerable.Range(1, 5).Select(index => new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            TemperatureC = Random.Shared.Next(-20, 55),
            Summary = Summaries[Random.Shared.Next(Summaries.Length)]
        })
        .ToArray();
    }
}
