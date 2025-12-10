namespace PoWebApp
{
    public static class Extensions
    {
        public static IHostBuilder AddConfiguration(this IHostBuilder host)
        {
            host.ConfigureAppConfiguration(c =>
            {
                c.AddJsonFile("appsettings.Development.json");
                c.AddEnvironmentVariables();
            });

            return host;
        }
    }
}


