param location string = resourceGroup().location
param environment string
param createdBy string = 'timengo'
param tags object

var deploymentStorageAccountName = '${environment}deployment${uniqueString(subscription().id)}'

resource DeploymentStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: deploymentStorageAccountName
  kind: 'StorageV2'
  location: location
  tags: union(tags, {
    'Created By': createdBy
  })
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion:'TLS1_2'

  }
}

resource DeploymentStorageAccountBlobDSC 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${deploymentStorageAccountName}/default/dsc'
  dependsOn: [
    DeploymentStorageAccount
  ]
}

output name string = DeploymentStorageAccount.name
