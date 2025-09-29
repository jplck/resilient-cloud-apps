param containerAppEnvId string

param location string = resourceGroup().location

param appName string = 'contonance-backend'

param eventHubNamespaceName string

param eventHubName string

param eventHubAuthRuleName string

param appInsightsName string

param storageAccountName string

param registryOwner string

param imageTag string

param appConfigurationName string

var EHConnectionStringSecretName = 'eventhub-connection-string'
var StorageLeaseBlobName = 'keda-blob-lease'

resource rule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' existing = {
  name: '${eventHubNamespaceName}/${eventHubName}/${eventHubAuthRuleName}'
}

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' existing = {
  name: appConfigurationName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-01-01-preview' existing = {
  name: eventHubNamespaceName
}

resource containerApp 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: appName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnvId
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: EHConnectionStringSecretName
          value: rule.listKeys().primaryConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: 'ghcr.io/${registryOwner}/reliable-apps/${appName}:${imageTag}'
          resources: {
            cpu: json('.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'PORT'
              value: '8080'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'ENTERPRISE_WAREHOUSE_BACKEND_URL'
              value: 'http://enterprise-warehouse-backend/api/message/receive'
            }
            {
              name: 'ApplicationInsights__ConnectionString'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'EventHub__EventHubName'
              value: eventHubName
            }
            {
              name: 'EventHub__EventHubNamespace'
              value: eventHubNamespaceName
            }
            {
              name: 'EventHub__StorageAccountName'
              value: storageAccount.name
            }
            {
              name: 'AppConfiguration__Endpoint'
              value: appConfiguration.properties.endpoint
            }
          ]
          probes: [
            {
              httpGet: {
                path: '/ping'
                port: 8080
              }
              initialDelaySeconds: 5
              periodSeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
        rules: [
          {
            name: 'sb-keda-scale'
            custom: {
              type: 'azure-eventhub'
              metadata: {
                consumerGroup: '$Default'
                unprocessedEventThreshold: '64'
                blobContainer: StorageLeaseBlobName
                checkpointStrategy: 'blobMetadata'
                storageAccountName: storageAccount.name
              }
              auth: [
                {
                  secretRef: EHConnectionStringSecretName
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

// Grant Storage Blob Data Contributor role to the managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, storageAccount.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
}

// Grant Azure Event Hubs Data Receiver role to the managed identity
resource eventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, eventHubNamespace.id, 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde')
  scope: eventHubNamespace
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde') // Azure Event Hubs Data Receiver
    principalType: 'ServicePrincipal'
  }
}

// Grant App Configuration Data Reader role to the managed identity
resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, appConfiguration.id, '516239f1-63e1-4d78-a4de-a74fb236a071')
  scope: appConfiguration
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '516239f1-63e1-4d78-a4de-a74fb236a071') // App Configuration Data Reader
    principalType: 'ServicePrincipal'
  }
}
