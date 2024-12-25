param location string = resourceGroup().location
param environment string
param createdBy string
param tags object
param iso_sqlserverURL string 
param iso_exchangeURL string

param baseTime string = utcNow('u')

@description('Number of days of retention. Free plans can only have 7 days, Standalone and Log Analytics plans include 30 days for free')
@minValue(7)
@maxValue(730)
param dataRetention int = 30

@description('Service Tier: Free, Standalone, PerNode, or PerGB2018')
@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
])
param serviceTier string = 'PerGB2018'

//var vnetconfig = loadJsonContent('../configs/vnet.json')

var keyVaultName = '${environment}-keyvault-${uniqueString(subscription().id)}'
var automationAccountName = '${environment}-plat-mgmt-automation'
var logAnalyticsName = '${environment}-plat-mgmt-loganalytics'
var deploymentStorageAccountName = '${environment}deployment${uniqueString(subscription().id)}'


var accountSasProperties = {
  signedServices: 'b'
  signedPermission: 'r'
  signedExpiry: dateTimeAdd(baseTime, 'P6MT1H')
  signedResourceTypes: 'o'
}

resource DeploymentStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: deploymentStorageAccountName
}

var storageURL  = DeploymentStorageAccount.properties.primaryEndpoints.blob
var storageSASToken  = DeploymentStorageAccount.listAccountSas('2022-09-01', accountSasProperties).accountSasToken


resource AutomationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  tags: union(tags, {
    'Created By': createdBy
  })
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: { '${uaiKeyvaultPlatformCoreAccess.id}':{} }
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  dependsOn: []
  
}

resource LogAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: union(tags, {
    'Created By': createdBy
  })
  properties: {
    sku: {
      name: serviceTier
    }
    features: {
      searchVersion: '1'
    }
    retentionInDays: dataRetention
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

//Grant Automation account Key Vault Secrets User permissions in Keyvault, to allow it to read secrets
module roleAuthorization 'bicep/keyvault.auth.bicep' = {
    name: 'roleAuthorization'
    params: {
      accountName: ''
      KeyVaultName: keyVaultName
      principalId: AutomationAccount.identity.principalId
      roleDefinition: 'Key Vault Secrets User'
      principalType: 'ServicePrincipal'
    }
}



// Add the Automation account's managed identity to the permissions of the Automation account.
// This is needed for the runbook job, to be able to trigger a recompile of the mof files.


@description('the role definition is collected')
resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'f353d9bd-d4a6-484e-a77a-8050b599b867' // Automation Contributor
}

@description('add the roledefinition to access control of the automation account')
resource roleAuthorizationKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope:AutomationAccount
  name: guid('automation-rbac', AutomationAccount.id, resourceGroup().id)
  properties: {
      principalId: AutomationAccount.identity.principalId
      roleDefinitionId: roleDefinition.id
      principalType: 'ServicePrincipal'
  }
}



// Handle DSC Modules.

// Wait resource

resource Wait 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'Wait30Seconds'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '9.1'
    timeout: 'PT5M'
    arguments: ''
    scriptContent: '''Start-Sleep -Seconds 30'''
    cleanupPreference: 'Always'
    retentionInterval: 'PT2H'
  }
}



var dscModules1 = [
  {
    name: 'ActiveDirectoryDsc'
    version: '6.3.0'
  }
  {
    name: 'xPSDesiredStateConfiguration'
    version: '9.1.0'
  }
  {
    name: 'WebAdministrationDsc'
    version: '4.1.0'
  }
  {
    name: 'ComputerManagementDsc'
    version: '9.0.0'
  }
  {
    name: 'DnsServerDsc'
    version: '3.0.0'
  }
]
  var dscModules2 = [
  {
    name: 'LanguageDsc'
    version: '1.0.0.0'
  }
  {
    name: 'NetworkingDsc'
    version: '9.0.0'
  }
  {
    name: 'PSDscResources'
    version: '2.12.0.0'
  }
  {
    name: 'StorageDSC'
    version: '5.1.0'
  }
  {
    name: 'SqlServerDsc'
    version: '16.5.0'
  }
  ]
  var dscModules3 = [
  // {
  //   name: 'CertificateDsc'
  //   version: '6.0.0'
  // }
  {
    name: 'DSCR_FileContent'
    version: '2.4.2'
  }
  {
    name: 'DFSDsc'
    version: '5.1.0'
  }
  {
    name: 'ActiveDirectoryCSDsc'
    version: '5.0.0'
  }
  {
    name:'PowerShellModule'
    version:'0.3.0'
  }
  {
    name: 'VSTSAgent'
    version: '2.0.14'
  }
]
var dscModules4 = [

  {
    name: 'cNtfsAccessControl'
    version: '1.4.1'
  }
  {
    name: 'AdfsDsc'
    version: '1.4.0'
  }
  {
    name: 'DSCR_Application'
    version: '4.1.1'
  }
  {
    name: 'cSecurityOptions'
    version: '3.1.3'
  }
  {
    name: 'ExchangeDsc'
    version: '2.0.0'
  }
]
var dscModules5 = [
  {
    name: 'xRemoteDesktopSessionHost'
    version: '2.1.0'
  }
  {
    name: 'cChoco'
    version: '2.6.0.0'
  }
  {
    name: 'AuditPolicyDsc'
    version: '1.4.0.0'
    
  }
]

//Importing is split into sections of 5 due to Azure Automation limits as per end of year 2022
// https://github.com/MicrosoftDocs/azure-docs/blob/main/includes/azure-automation-service-limits.md
// Maximum number of modules that can be imported every 30 seconds per Automation account: 5

resource DSCModule1 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = [for module in dscModules1: {
  parent: AutomationAccount
  name: module.name
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/${module.name}/${module.version}'
      version: module.version
    }
  }
  dependsOn:[
    //dscAzureModules2
    Wait
  ]
}]

resource DSCModule2 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = [for module in dscModules2: {
  parent: AutomationAccount
  name: module.name
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/${module.name}/${module.version}'
      version: module.version
    }
  }
  dependsOn:[
    DSCModule1
    Wait
  ]
}]

resource DSCModule3 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = [for module in dscModules3: {
  parent: AutomationAccount
  name: module.name
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/${module.name}/${module.version}'
      version: module.version
    }
  }
  dependsOn:[
    DSCModule1
    DSCModule2
    Wait
  ]
}]

resource DSCModule4 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = [for module in dscModules4: {
  parent: AutomationAccount
  name: module.name
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/${module.name}/${module.version}'
      version: module.version
    }
  }
  dependsOn:[
    DSCModule1
    DSCModule2
    DSCModule3
    Wait
  ]
}]

resource DSCModule5 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = [for module in dscModules5: {
  parent: AutomationAccount
  name: module.name
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/${module.name}/${module.version}'
      version: module.version
    }
  }
  dependsOn:[
    DSCModule1
    DSCModule2
    DSCModule3
    DSCModule4
    Wait
  ]
}]



// PSGallery version hasn't been updated since 2018, but fixes are in the code on Github.
// We need the fix, as it fails otherwise.
// Module has been renamed as both the origniale name and DSC resource (ADCSTemplate) collides with a DSC resource in module ActiveDirectoryCSDsc.
// ActiveDirectoryCSDsc is used to configure the Certificate Authority - Rename part can be avoided, by moving template import part to i.e. Domain Controller.
// Until something newer is relased, it needs to be installed from here.
var storageURIADCSTemplate = '${storageURL}${'dsc/ADCSTemplateDSC.zip?'}${storageSASToken}'
resource dscADCSTemplate 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = {
  parent: AutomationAccount
  name: 'ADCSTemplateDSC'
  properties: {
    contentLink: {
      uri: storageURIADCSTemplate
    }
  }
}


// This current latest version from december 2022 contains a fix, which allows us to get rid of a lot of custom code to get certificates.
resource dscCertificateDsc 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = {
  parent: AutomationAccount
  name: 'CertificateDsc'
  properties: {
    contentLink: {
      uri: 'https://psg-prod-eastus.azureedge.net/packages/certificatedsc.6.0.0-preview0001.nupkg'
      version: '6.0.0'
    }
  }
}

// This is a custom module, containing a few generic functions to minimize code in Automation DSC scripts.
var storageURIDSSsetupDSC = '${storageURL}${'dsc/DSSsetupDSC.zip?'}${storageSASToken}'
resource dscDSSsetup 'Microsoft.Automation/automationAccounts/modules@2023-11-01' = {
  parent: AutomationAccount
  name: 'DSSsetupDSC'
  properties: {
    contentLink: {
      uri: storageURIDSSsetupDSC
    }
  }
}



// Set Automation Variables

resource Environment 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'Environment'
  properties: {
    value: '"${environment}"'
    description: 'Hvilket miljø - ${environment}'
    isEncrypted: false
  }
}

resource DomainName 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'DomainName'
  properties: {
    value: '"${environment}domstolene.dk"'
    description: 'Indeholder DomainName for ${environment} miljøet'
    isEncrypted: false
  }
}

resource DMZDomainName 'Microsoft.Automation/automationAccounts/variables@2022-08-08' = {
  parent: AutomationAccount
  name: 'DMZDomainName'
  properties: {
    value: '"dmz-${environment}domstolene.dk"'
    description: 'Indeholder DMZ DomainName for ${environment} miljøet'
    isEncrypted: false
  }
}

resource iso_ExchangeURL 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'iso_ExchangeURL'
  properties: {
    value: '"${iso_exchangeURL}"'
    description: 'Indeholder Storage Account Url for Exchange ISO fil i Utility'
    isEncrypted: false
  }
}


resource iso_SqlserverURL 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'iso_SqlServerURL'
  properties: {
    value: '"${iso_sqlserverURL}"'
    description: 'Indeholder Storage Account Url for SQL Server ISO fil i Utility'
    isEncrypted: false
  }
}

// Used by DomainController and CERT to downlaod files from the storage account.
resource DeploymentStorageAccountUrl 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'DeploymentStorageAccountUrl'
  properties: {
    value: '"${DeploymentStorageAccount.properties.primaryEndpoints.blob}"'
    description: 'Indeholder Deployment Storage Account Url for ${environment} miljøet'
    isEncrypted: false
  }
}

// Used by DomainController and CERT to downlaod files from the storage account.
resource DeploymentStorageAccountSasToken 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'DeploymentStorageAccountSasToken'
  properties: {
    value: '"${DeploymentStorageAccount.listAccountSas('2022-09-01', accountSasProperties).accountSasToken}"'
    description: 'Indeholder SasToken for ${environment} miljøet'
    isEncrypted: false
  }
}
resource DeploymentKeyVault 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: AutomationAccount
  name: 'KeyVaultName'
  properties: {
    value: '"${keyVaultName}"'
    description: 'Indeholder KeyVault navn for ${environment} miljøet'
    isEncrypted: false
  }
}

