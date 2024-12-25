param location string = resourceGroup().location
//param environment string
param createdBy string = 'timengo'
param tags object
@description('the name of the keyvault')
param KeyVaultName string

@description('Specifies whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
param enabledForDeployment bool = false

@description('Specifies whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.')
param enabledForDiskEncryption bool = false

@description('Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true

@description('Specifies the Azure Active Directory tenant ID that should be used for authenticating requests to the key vault. Get it by using Get-AzSubscription cmdlet.')
param tenantId string = subscription().tenantId

@description('Specifies whether the key vault is a standard vault or a premium vault.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

param baseTime string = utcNow('u')
//var managementResourceGroupName = '${environment}-plat-mgmt'
//var KeyVaultName = '${environment}-keyvault-${uniqueString(subscription().id)}'
//var logAnalyticsName = '${environment}-plat-mgmt-loganalytics'

//Load roleassignments - file was renamed from <environment>-roleassignments.json to roleassignments.json in the pipeline, for Bicep to be able to consume it.
var roleassignments = loadJsonContent('../configs/roleassignments.json')


//Only run this if they keyvault does not exist
  resource KeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: KeyVaultName
  location: location
  tags: union(tags, {
    'Created By': createdBy
  })
  properties: {
    tenantId: tenantId
    sku: {
      name: skuName
      family: 'A'
    }

    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: true
  }
}

 // Grant all approved users access to see secrets in Keyvault
 module roleAuthorizationView '../bicep/keyvault.auth.bicep' = if(!(roleassignments.Viewer.objectid == 'example')) {
  name: 'roleAuthorizationView-${uniqueString(baseTime)}'
  params: {
    accountName: ''
    principalId: roleassignments.Viewer.objectid
    roleDefinition: 'Key Vault Reader'
    principalType: 'Group'
    KeyVaultName: KeyVaultName
  }
  dependsOn:[ KeyVault ]
}

 // Grant all admins  access to see secrets and passwords in Keyvault
 module roleAuthorizationAdmin '../bicep/keyvault.auth.bicep' = if(!(roleassignments.Viewer.objectid == 'example')) {
  name: 'roleAuthorizationAdmin-${uniqueString(baseTime)}'
  params: {
    accountName: ''
    principalId: roleassignments.Admins.objectid
    roleDefinition: 'Key Vault Secrets Officer'
    principalType: 'Group'
    KeyVaultName: KeyVaultName
  }
  dependsOn:[ KeyVault ]
}

module roleAuthorizationAdminCerts '../bicep/keyvault.auth.bicep' = if(!(roleassignments.Viewer.objectid == 'example')) {
  name: 'roleAuthorizationAdminCerts-${uniqueString(baseTime)}'
  params: {
    accountName:''
    principalId: roleassignments.Admins.objectid
    roleDefinition: 'Key Vault Certificates Officer'
    principalType:'Group'
    KeyVaultName: KeyVaultName
  }
  dependsOn:[ KeyVault ]
}


resource uaiKeyvaultAccess 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uaiKeyvaultCertificates'
  location: location
}

module roleAuthorizationuaiKeyVaultSecret '../bicep/keyvault.auth.bicep' = {
  name: 'roleAuthorizationuaiKeyVaultSecret-${uniqueString(baseTime)}'
  params: {
    accountName: ''
    principalId: uaiKeyvaultAccess.properties.principalId
    roleDefinition: 'Key Vault Secrets Officer'
    principalType: 'ServicePrincipal'
    KeyVaultName: KeyVaultName
  }
  dependsOn:[ 
    KeyVault 
  ]
}

module roleAuthorizationuaiKeyVaultCerts '../bicep/keyvault.auth.bicep' = {
  name: 'roleAuthorizationuaiKeyVaultCerts-${uniqueString(baseTime)}'
  params: {
    accountName: ''
    principalId: uaiKeyvaultAccess.properties.principalId
    roleDefinition: 'Key Vault Certificates Officer'
    principalType:'ServicePrincipal'
    KeyVaultName: KeyVaultName
  }
  dependsOn:[ 
    KeyVault 
  ]
}
