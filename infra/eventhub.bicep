@description('Specifies the Azure location for all resources.')
param location string = resourceGroup().location

param eventHubNamespaceName string
param eventHubName string

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    // using a single partition only for demo purposes
    partitionCount: 1
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 1
    }
  }
}

resource eventHub_ListenSend 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' = {
  parent: eventHub
  name: 'ListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }
}

output eventHubName string = eventHubName
output eventHubNamespaceName string = eventHubNamespaceName
output authRuleName string = eventHub_ListenSend.name
output authRulePrimaryConnectionString string = listKeys(eventHub_ListenSend.id, '2021-01-01-preview').primaryConnectionString
