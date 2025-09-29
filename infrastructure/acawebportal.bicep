param containerAppEnvId string

param location string = resourceGroup().location

param appName string = 'contonance-web-portal'

param appInsightsName string

param registryOwner string

param imageTag string

param storageAccountName string

param containerName string

param appConfigurationName string

param eventHubNamespaceName string

param eventHubName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: storageAccountName
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' existing = {
  name: containerName
}

resource appConfiguration 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' existing = {
  name: appConfigurationName
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
              name: 'ApplicationInsights__ConnectionString'
              value: appInsights.properties.ConnectionString
            }
            {
              name: 'AzureOpenAiServiceEndpoint'
              value: ''
            }
            {
              name: 'AzureOpenAiKey'
              value: ''
            }
            {
              name: 'AzureOpenAiDeployment'
              value: ''
            }
            {
              name: 'AzureCognitiveSearchServiceEndpoint'
              value: ''
            }
            {
              name: 'AzureCognitiveSearchKey'
              value: ''
            }
            {
              name: 'AzureCognitiveSearchIndexName'
              value: ''
            }
            {
              name: 'AzureBlobStorageAccountName'
              value: storageAccount.name
            }
            {
              name: 'AzureBlobContainerUrl'
              value: 'https://${storageAccount.name}.blob.${environment().suffixes.storage}/${storageContainer.name}'
            }
            {
              name: 'AppConfiguration__Endpoint'
              value: appConfiguration.properties.endpoint
            }
            {
              name: 'CONTONANCE_BACKEND_URL'
              value: 'http://contonance-backend/'
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
              name: 'AzureOpenAiServiceEnabled'
              value: 'false'
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
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// RBAC role assignments for managed identity
// Grant Storage Blob Data Contributor role to the managed identity
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, storageAccount.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: storageAccount
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
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

// Grant Azure Event Hubs Data Sender role to the managed identity
resource eventHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerApp.id, eventHubNamespace.id, '2b629674-e913-4c01-ae53-ef4638d8f975')
  scope: eventHubNamespace
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975') // Azure Event Hubs Data Sender
    principalType: 'ServicePrincipal'
  }
}
