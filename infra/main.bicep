@description('Location resources.')
param location string

@description('Specifies a project name that is used to generate the Event Hub name and the Namespace name.')
param environmentName string

@description('Provide the name of the GitHub Container Registry owner.')
param registryOwner string

@description('The tag of the image to be deployed. This should be a valid tag that exists in the GitHub Container Registry. Use latest if you want to use the latest image.')
param imageTag string

targetScope = 'subscription'

var aiStorageContainerName = 'ai-data'

resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: '${environmentName}-rg'
  location: location
}

module logging 'logging.bicep' = {
  name: 'logging'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceName: 'log-${environmentName}'
    applicationInsightsName: 'appi-${environmentName}'
  }
}

module workbook 'workbook.bicep' = {
  name: 'workbook'
  scope: rg
  params: {
    location: location
    workbookId: '5caf5fbb-125c-4cfb-a3b3-de2c5a27ff08'
    workbookDisplayName: 'reliable-apps-new-${environmentName}'
    workbookSourceId: logging.outputs.appInsightsId
  }
}

module eventhub 'eventhub.bicep' = {
  name: 'eventhub'
  scope: rg
  params: {
    location: location
    eventHubNamespaceName: 'evhns-${environmentName}'
    eventHubName: 'events'
  }
}

module cosmosdbsql 'cosmosdb-sql.bicep' = {
  name: 'cosmosdbsql'
  scope: rg
  params: {
    location: location
    cosmosdbAccountName: 'dbs${environmentName}'
    cosmosdbDatabaseName: 'repair_parts'
    autoscaleMaxThroughput: 400
  }
}

module eh_storage 'storage.bicep' = {
  name: 'ehstorage'
  scope: rg
  params: {
    location: location
    storageAccountName: 'ehst${environmentName}'
    containerNames: []
  }
}

module ai_storage 'storage.bicep' = {
  name: 'aistorage'
  scope: rg
  params: {
    location: location
    storageAccountName: 'aist${environmentName}'
    containerNames: [
      aiStorageContainerName
    ]
  }
}

module appconfig 'appconfig.bicep' = {
  name: 'appconfig'
  scope: rg
  params: {
    location: location
    appConfigStoreName: 'appcs-${environmentName}'
  }
}

module acaenv 'acaenv.bicep' = {
  name: 'acaenv'
  scope: rg
  params: {
    containerAppEnvName: 'aca-${environmentName}'
    location: location
    logAnalyticsWorkspaceName: logging.outputs.logAnalyticsWorkspaceName
  }
}

module acareceiver 'acacontonancebackend.bicep' = {
  name: 'acacontonancebackend'
  scope: rg
  params: {
    containerAppEnvId: acaenv.outputs.containerAppEnvId
    location: location
    appInsightsName: logging.outputs.appInsightsName
    eventHubName: eventhub.outputs.eventHubName
    eventHubNamespaceName: eventhub.outputs.eventHubNamespaceName
    eventHubAuthRuleName: eventhub.outputs.authRuleName
    storageConnectionString: eh_storage.outputs.blobStorageConnectionString
    registryOwner: registryOwner
    imageTag: imageTag
    appConfigurationName: appconfig.outputs.appConfigurationName
  }
}

module acasink 'acawarehouse.bicep' = {
  name: 'acawarehouse'
  scope: rg
  params: {
    containerAppEnvId: acaenv.outputs.containerAppEnvId
    location: location
    appInsightsName: logging.outputs.appInsightsName
    registryOwner: registryOwner
    imageTag: imageTag
    cosmosDbName: cosmosdbsql.outputs.name
  }
}

module acawebportal 'acawebportal.bicep' = {
  name: 'acawebportal'
  scope: rg
  params: {
    containerAppEnvId: acaenv.outputs.containerAppEnvId
    location: location
    appInsightsName: logging.outputs.appInsightsName
    registryOwner: registryOwner
    imageTag: imageTag
    storageAccountName: ai_storage.outputs.storageAccountName
    containerName: aiStorageContainerName
    appConfigurationName: appconfig.outputs.appConfigurationName
    eventHubName: eventhub.outputs.eventHubName
    eventHubAuthRuleName: eventhub.outputs.authRuleName
    eventHubNamespaceName: eventhub.outputs.eventHubNamespaceName
  }
}
/*
module ai 'ai.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    location: location
    openaiDeploymentName: 'openai-${projectName}'
    documentIntDeploymentName: 'documentInt-${projectName}'
    projectName: projectName
  }
}*/

output ApplicationInsights__ConnectionString string = logging.outputs.applicationInsightsConnectionString
output EventHub__EventHubConnectionString string = eventhub.outputs.authRulePrimaryConnectionString
output EventHub__EventHubName string = eventhub.outputs.eventHubName
output EventHub__BlobConnectionString string = eh_storage.outputs.blobStorageConnectionString
output ConnectionStrings__CosmosApi string = cosmosdbsql.outputs.connectionString
output AppConfiguration__ConnectionString string = appconfig.outputs.connectionString
output ASPNETCORE_ENVIRONMENT string = 'Development'
output CONTONANCE_BACKEND_URL string = 'http://localhost:5025/'
output ENTERPRISE_WAREHOUSE_BACKEND_URL string = 'http://localhost:5027/'
output VERSION string = 'dev version'
output AzureOpenAiServiceEnabled bool = false
