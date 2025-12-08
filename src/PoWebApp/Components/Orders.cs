using Azure.Storage.Queues;

namespace PoWebApp.Components
{
    public class Orders
    {
        public async Task AddOrderMessageToQueueAsync( )
        {
            var connectionString = Environment.GetEnvironmentVariable("AzureWebJobsStorage");
            var queueName = "orders-queue";
            var message = "New order placed at " + DateTime.UtcNow.ToString("o");

            var queueClient = new QueueClient(connectionString, queueName);
            await queueClient.CreateIfNotExistsAsync();
            await queueClient.SendMessageAsync(message);
        }
    }
}
