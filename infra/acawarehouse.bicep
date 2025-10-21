param containerAppEnvId string

param location string = resourceGroup().location

param appName string = 'enterprise-warehouse-backend'

param appInsightsName string

param registryOwner string

param imageTag string

param cosmosDbName string

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2021-01-15' existing = {
  name: cosmosDbName
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
              name: 'ENTERPRISE_WAREHOUSE_BACKEND_URL'
              value: 'http://enterprise-warehouse-backend/api/message/receive'
            }
            {
              name: 'CosmosDb__AccountEndpoint'
              value: cosmosDb.properties.documentEndpoint
            }
            {
              name: 'CosmosDb__DatabaseName'
              value: 'repair_parts'
            }
            {
              name: 'ApplicationInsights__ConnectionString'
              value: appInsights.properties.ConnectionString
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

// Create a custom SQL role definition for data access
var roleDefinitionId = '11111111-1111-1111-1111-111111111111'

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-11-15' = {
  parent: cosmosDb
  name: roleDefinitionId
  properties: {
    roleName: 'Enterprise Warehouse Data Contributor'
    type: 'CustomRole'
    assignableScopes: [
      cosmosDb.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
      }
    ]
  }
}

// Grant Cosmos DB SQL role to the managed identity
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmosDb
  name: guid(containerApp.id, cosmosDb.id, roleDefinitionId)
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: containerApp.identity.principalId
    scope: cosmosDb.id
  }
}
