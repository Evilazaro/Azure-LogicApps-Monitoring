using Azure.Storage.Queues;

namespace PoWebApp.Components
{
    public class Orders
    {
        public async Task AddOrderMessageToQueueAsync(string connectionString, string queueName, string message)
        {
            var queueClient = new QueueClient(connectionString, queueName);
            await queueClient.CreateIfNotExistsAsync();
            await queueClient.SendMessageAsync(message);
        }
    }
}
