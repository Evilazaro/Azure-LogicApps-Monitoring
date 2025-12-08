using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.Extensions.Configuration;

namespace PoWebApp.Components
{
    public class Orders
    {
        private readonly IConfiguration _configuration;

        public Orders(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task<int> AddOrderMessageToQueueAsync()
        {
            try
            {
                var queueName = "orders-queue";
                var queueServiceUri = _configuration.GetValue<string>("StorageConnection:queueServiceUri");
                var queueUri = new Uri($"{queueServiceUri.TrimEnd('/')}/{queueName}");

                var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    TenantId = "0e2ff29e-431a-420b-8a46-c6f39106927b"
                });

                var queueClient = new QueueClient(queueUri, credential);
                await queueClient.CreateIfNotExistsAsync();

                for (int i = 0; i <= 500; i++)
                {
                    var orderNumber = Guid.NewGuid().ToString();
                    var message = $"New order {orderNumber} placed at : {DateTime.UtcNow:o}";

                    await queueClient.SendMessageAsync(message); 
                }

                return 500;
            }
            catch (Exception)
            {
                throw;
            }
        }
    }
}

