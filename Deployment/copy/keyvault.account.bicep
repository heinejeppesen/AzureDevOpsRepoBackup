param baseTime string = utcNow('u')
param environment string
param createdBy string = 'timengo'

@description('Name of the account to be created in KeyVault')
param accountName string
@allowed([
  'ServiceAccount'
  'LocalAdmin'
  'DomainAdmin'
  'DMZDomainAdmin'
  'DMZServiceAccount'
  'SQLLocal'
])
param accountType string
@description('ID of the group to be given access to the keys')
param accountRolePrincipalId string

@description('Which application the account belongs to')
param accountApplication string

var managementResourceGroupName = '${environment}-plat-mgmt'

var KeyVaultName = '${environment}-keyvault-${uniqueString(subscription().id)}'

//Add default values to Keyvault
module SecretSetup '../bicep/keyvault.secret.bicep' = {
 scope: resourceGroup(managementResourceGroupName)
 name: '${accountName}-CreateInKeyVault-${uniqueString(baseTime)}'
 params: {
   environment: environment
   secretName: accountName
   applicationName: accountApplication
   contentTypeName: accountType
   createdBy: createdBy
 }
 dependsOn:[
]
}

module roleAuthorizationSetup'../bicep/keyvault.auth.bicep' = if(!(accountRolePrincipalId == 'example')) {
    name: '${accountName}-roleAuthorization-${uniqueString(baseTime)}'
    params: {
      accountName: accountName
      KeyVaultName: KeyVaultName
      principalId: accountRolePrincipalId
      roleDefinition: 'Key Vault Secrets Officer'
      principalType: 'Group'
    }
    dependsOn:[
      SecretSetup
    ]
}

