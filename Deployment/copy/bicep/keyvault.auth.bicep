// https://www.jvandertil.nl/posts/2022-06-22_easyazurerbacwithbicep/

//param environment string
@description('Serviceaccount (secret) som der skal gives permission til at tilgå')
param accountName string 
@description('Principal / gruppe, der skal have adgang')
param principalId string

@description('Account/Gruppe type')
@allowed([
    'User' 
    'Group' 
    'ServicePrincipal' 
])
param principalType string

@description('State whether the resource exists or not')
param existAlready bool = false

@description('the name of the keyvault')
param KeyVaultName string

@allowed([
    'Key Vault Reader'
    'Key Vault Secrets Officer'
    'Key Vault Secrets User'
    'Key Vault Certificates Officer'
])
param roleDefinition string

//var KeyVaultName = '${environment}-keyvault-${uniqueString(subscription().id)}'

var roles = {
    // See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles for these mappings and more.
    'Key Vault Reader': '/providers/Microsoft.Authorization/roleDefinitions/21090545-7ca7-4776-b22c-e363652d74d2'
    'Key Vault Secrets Officer': '/providers/Microsoft.Authorization/roleDefinitions/b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
    'Key Vault Secrets User': '/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
    'Key Vault Certificates Officer': '/providers/Microsoft.Authorization/roleDefinitions/a4417e6f-fecd-4de8-b567-7b0420556985'
}


var roleDefinitionId = roles[roleDefinition]

resource keyvaultAccount 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
        name: KeyVaultName
}
//if (!empty(accountName)) 
resource keyvaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' existing = {
    parent:keyvaultAccount
    name: accountName
}
 
// Apparently having a conditional on 'Scope' isn't supported/working at end of 2022
// See this issue for more info https://github.com/Azure/bicep/issues/7367
// Workaround is spliting into two resources


// Handle Keyvault permissions
resource roleAuthorizationKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (empty((accountName)) && (existAlready == false)) {
    // Generate a unique but deterministic resource name
    scope:keyvaultAccount
    name: guid('keyvault-rbac', keyvaultAccount.id, resourceGroup().id, principalId, roleDefinitionId)
    properties: {
        principalId: principalId
        roleDefinitionId: roleDefinitionId
        principalType: principalType
    }
}

// Handle secret permissions
resource roleAuthorizationSecret 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty((accountName)) && (existAlready == false)) {
    // Generate a unique but deterministic resource name
    scope: keyvaultSecret
    name: guid('keyvault-rbac', keyvaultSecret.id, resourceGroup().id, principalId, roleDefinitionId)
    properties: {
        principalId: principalId
        roleDefinitionId: roleDefinitionId
        principalType: principalType
    }
}


