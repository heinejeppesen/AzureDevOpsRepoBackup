param environment string
param secretName string
param applicationName string
param contentTypeName string = 'ServiceAccount'
@description('Specifies the value of the secret that you want to create.')
@secure()
param secretValue string = '${toUpper(uniqueString(resourceGroup().id))}-${newGuid()}'
param createdBy string
param existAlready bool = false


var KeyVaultName = '${environment}-keyvault-${uniqueString(subscription().id)}'



resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: KeyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if(existAlready == false) {
  parent: kv
  name: secretName
  tags: {
    Applikation : applicationName
    'Created By': createdBy
  }
  properties: {
    attributes: {
      enabled: true
    }
    value: secretValue
    contentType: contentTypeName
  }
}
