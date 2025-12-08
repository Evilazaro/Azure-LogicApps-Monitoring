using Azure.Identity;
using Azure.Storage.Queues;

namespace PoWebApp.Components
{
    public class Orders
    {
        public void AddOrderMessageToQueueAsync()
        {
            try
            {
                IConfiguration configuration;

                var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");

                if (environment == "Production")
                {
                    configuration = new ConfigurationBuilder()
                       .AddJsonFile("appsettings.json")
                       .Build();
                }
                else
                {
                    configuration = new ConfigurationBuilder()
                       .AddUserSecrets(assembly: typeof(PoWebApp.Components.App).Assembly)
                       .Build();
                }

                var queueServiceUri = configuration.GetConnectionString("StorageConnection:queueServiceUri");

                var queueName = "orders-queue";
                
                var orderNumber = Guid.NewGuid().ToString();
                var message = $"New order {orderNumber} placed at : {DateTime.UtcNow.ToString("o")}";

                // Use DefaultAzureCredential for Entra ID authentication
                var credential = new DefaultAzureCredential();
                var queueUri = new Uri($"{queueServiceUri.TrimEnd('/')}/{queueName}");

                var queueClient = new QueueClient(queueUri, credential);

                queueClient.CreateIfNotExistsAsync();
                queueClient.SendMessageAsync(message);
            }
            catch (Exception)
            {

                throw;
            }
        }
    }
}

