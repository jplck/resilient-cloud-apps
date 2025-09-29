using AspNetCoreRateLimit;
using Microsoft.ApplicationInsights.Extensibility;
using Azure.Identity;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json").AddEnvironmentVariables();

builder.Services.AddControllers(options =>
{
    options.RespectBrowserAcceptHeader = true;
});

builder.Services.AddLogging(config =>
{
    config.AddDebug();
    config.AddConsole();
});

builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.DeveloperMode = true; // Only for demo purposes, do not use in production!
});
builder.Services.AddSingleton<ITelemetryInitializer>(_ => new CloudRoleNameTelemetryInitializer("EnterpriseWarehouse.Backend"));

builder.Services.AddOptions();

builder.Services.AddMemoryCache();
builder.Services.Configure<IpRateLimitOptions>(builder.Configuration.GetSection("IpRateLimiting"));
builder.Services.Configure<IpRateLimitPolicies>(builder.Configuration.GetSection("IpRateLimitPolicies"));
builder.Services.AddInMemoryRateLimiting();
builder.Services.AddSingleton<IRateLimitConfiguration, RateLimitConfiguration>();

builder.Services.AddSingleton(
    s =>
    {
        // Use managed identity for Cosmos DB when account endpoint is available
        var cosmosAccountEndpoint = builder.Configuration.GetValue<string>("CosmosDb:AccountEndpoint");
        var cosmosConnectionString = builder.Configuration.GetConnectionString("CosmosApi");
        
        if (!string.IsNullOrEmpty(cosmosAccountEndpoint))
        {
            // Use managed identity with DefaultAzureCredential
            return new Microsoft.Azure.Cosmos.Fluent.CosmosClientBuilder(cosmosAccountEndpoint, new DefaultAzureCredential())
                .WithSerializerOptions(new Microsoft.Azure.Cosmos.CosmosSerializationOptions()
                {
                    PropertyNamingPolicy = Microsoft.Azure.Cosmos.CosmosPropertyNamingPolicy.CamelCase
                })
                .WithBulkExecution(false)
                .WithThrottlingRetryOptions(TimeSpan.FromSeconds(1), 1)
                .Build();
        }
        else if (!string.IsNullOrEmpty(cosmosConnectionString))
        {
            // Fallback to connection string for local development
            return new Microsoft.Azure.Cosmos.Fluent.CosmosClientBuilder(cosmosConnectionString)
                .WithSerializerOptions(new Microsoft.Azure.Cosmos.CosmosSerializationOptions()
                {
                    PropertyNamingPolicy = Microsoft.Azure.Cosmos.CosmosPropertyNamingPolicy.CamelCase
                })
                .WithBulkExecution(false)
                .WithThrottlingRetryOptions(TimeSpan.FromSeconds(1), 1)
                .Build();
        }
        else
        {
            throw new InvalidOperationException("Either CosmosDb:AccountEndpoint or ConnectionStrings:CosmosApi must be configured");
        }
    }
);

builder.Services.AddSingleton<IMessageStorageService, MessageCosmosSqlStorageService>();

var app = builder.Build();

app.MapControllers();

app.UseIpRateLimiting();

app.Run();
