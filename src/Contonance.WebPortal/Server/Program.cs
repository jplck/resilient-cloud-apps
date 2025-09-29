using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.Azure;
using Azure;
using Azure.Identity;
using Azure.Messaging.EventHubs.Producer;
using Contonance.Extensions;
using Contonance.WebPortal.Server.Clients;
using Contonance.WebPortal.Client;
using Microsoft.ApplicationInsights.AspNetCore.Extensions;

var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    // Workaround because blazorwasm debugger does not support envFile
    var root = Directory.GetCurrentDirectory();
    var dotenv = Path.Combine(root, "../../../local.env");
    DotEnv.Load(dotenv);
}

builder.Configuration
    .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", true, true)
    .AddEnvironmentVariables()
    .AddAzureAppConfiguration(options =>
{
    // Use managed identity for App Configuration when endpoint is available
    var appConfigEndpoint = builder.Configuration.GetValue<string>("AppConfiguration:Endpoint");
    var appConfigConnectionString = builder.Configuration.GetValue<string>("AppConfiguration:ConnectionString");
    
    if (!string.IsNullOrEmpty(appConfigEndpoint))
    {
        // Use managed identity with DefaultAzureCredential
        options.Connect(new Uri(appConfigEndpoint), new DefaultAzureCredential());
    }
    else if (!string.IsNullOrEmpty(appConfigConnectionString))
    {
        // Fallback to connection string for local development
        options.Connect(appConfigConnectionString);
    }
    
    options.UseFeatureFlags(featureFlags =>
    {
        featureFlags.CacheExpirationInterval = TimeSpan.FromSeconds(2);
    });
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
builder.Services.AddSingleton<ITelemetryInitializer>(_ => new CloudRoleNameTelemetryInitializer("Contonance.WebPortal.Server"));


builder.Services.AddAzureAppConfiguration();

// Configure Event Hub Producer with managed identity
var eventHubNamespace = builder.Configuration.GetValue<string>("EventHub:EventHubNamespace");
var eventHubName = builder.Configuration.GetValue<string>("EventHub:EventHubName");

if (!string.IsNullOrEmpty(eventHubNamespace) && !string.IsNullOrEmpty(eventHubName))
{
    // Register EventHubProducerClient directly
    var fullyQualifiedNamespace = $"{eventHubNamespace}.servicebus.windows.net";
    builder.Services.AddSingleton(serviceProvider =>
        new EventHubProducerClient(fullyQualifiedNamespace, eventHubName, new DefaultAzureCredential()));
}
else
{
    throw new InvalidOperationException("Both EventHub:EventHubNamespace and EventHub:EventHubName must be configured for managed identity authentication");
}

builder.Services.AddAzureClients(b =>
{

    // Configure Storage Blob client with managed identity
    var storageAccountName = builder.Configuration.GetValue<string>("AzureBlobStorageAccountName");
    if (!string.IsNullOrEmpty(storageAccountName))
    {
        // Use managed identity with DefaultAzureCredential
        var storageUri = new Uri($"https://{storageAccountName}.blob.core.windows.net");
        b.AddBlobServiceClient(storageUri).WithCredential(new DefaultAzureCredential());
    }

    //Added config to enable/disable Azure OpenAI Service DI for demo purposes
    if (builder.Configuration.GetValue<bool>("AzureOpenAiServiceEnabled")) {
        b.AddOpenAIClient(new Uri(builder.Configuration.GetNoEmptyStringOrThrow("AzureOpenAiServiceEndpoint")), new AzureKeyCredential(builder.Configuration.GetNoEmptyStringOrThrow("AzureOpenAiKey")));
    }
});

builder.Services
    .AddHttpClient<ContonanceBackendClient>()
    .AddPolicyConfiguration(ContonanceBackendClient.SelectPolicy, builder.Configuration);

builder.Services.AddControllersWithViews();
builder.Services.AddRazorPages();

builder.WebHost.UseStaticWebAssets();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseWebAssemblyDebugging();
}
else
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseAzureAppConfiguration();

app.UseHttpsRedirection();

app.UseBlazorFrameworkFiles();
app.UseStaticFiles();

app.UseRouting();

app.MapRazorPages();
app.MapControllers();
app.MapFallbackToFile("index.html", new StaticFileOptions()
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Cookies.Append("ai_connString", app.Configuration["ApplicationInsights:ConnectionString"]!);
    }
});

app.Run();