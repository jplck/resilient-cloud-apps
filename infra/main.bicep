@description('Location resources.')
param location string

param environmentName string

param registryOwner string

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
    storageAccountName: eh_storage.outputs.storageAccountName
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
    eventHubNamespaceName: eventhub.outputs.eventHubNamespaceName
  }
}
/*
module ai 'ai.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    location: location
    openaiDeploymentName: 'openai-${environmentName}'
    documentIntDeploymentName: 'documentInt-${environmentName}'
    projectName: environmentName
  }
}*/

output ApplicationInsights__ConnectionString string = logging.outputs.appInsightsInstrumentationKey
output EventHub__EventHubName string = eventhub.outputs.eventHubName
output EventHub__EventHubNamespace string = eventhub.outputs.eventHubNamespaceName
@secure()
output EventHub__BlobConnectionString string = eh_storage.outputs.blobStorageConnectionString
@secure()
output ConnectionStrings__CosmosApi string = cosmosdbsql.outputs.connectionString
@secure()
output AppConfiguration__ConnectionString string = appconfig.outputs.connectionString
