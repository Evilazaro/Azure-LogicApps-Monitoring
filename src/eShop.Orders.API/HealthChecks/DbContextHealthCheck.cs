using eShop.Orders.API.Data;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace eShop.Orders.API.HealthChecks;

/// <summary>
/// Health check for Entity Framework Core DbContext connectivity.
/// </summary>
public sealed class DbContextHealthCheck : IHealthCheck
{
    private readonly OrderDbContext _dbContext;
    private readonly ILogger<DbContextHealthCheck> _logger;

    public DbContextHealthCheck(OrderDbContext dbContext, ILogger<DbContextHealthCheck> logger)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Try to execute a simple query to verify database connectivity
            await _dbContext.Database.CanConnectAsync(cancellationToken);

            return HealthCheckResult.Healthy("Database connection is healthy");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database health check failed");

            return new HealthCheckResult(
                context.Registration.FailureStatus,
                description: "Database connection failed",
                exception: ex);
        }
    }
}