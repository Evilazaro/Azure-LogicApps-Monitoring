using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.Extensions.Configuration;

namespace PoWebApp.Components
{
    public class Orders
    {
        public void AddOrderMessageToQueueAsync()
        {
            try
            {
                IConfiguration configuration = new ConfigurationBuilder()
                       .AddJsonFile("appsettings.Development.json")
                       .Build();

                var queueServiceUri = configuration.GetConnectionString("queueServiceUri");

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

