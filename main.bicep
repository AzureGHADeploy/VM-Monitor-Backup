// ====================================================================
// PARAMETERS
// ====================================================================
@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The name of the virtual machine.')
param vmName string = 'TestVM'

@description('The name of the network interface.')
param nicName string = '${vmName}-nic'

@description('The name of the virtual network.')
param vnetName string = '${vmName}-vnet'

@description('The name of the subnet.')
param subnetName string = '${vmName}-subnet'

@description('The name of the public IP address.')
param publicIPName string = '${vmName}-pip'

@description('The name of the Network Security Group (NSG) for the VM.')
param nsgName string = '${vmName}-nsg'

@description('The size of the Virtual Machine (e.g., Standard_D2s_v3).')
param vmSize string = 'Standard_D2s_v3'

@description('The admin username for the Virtual Machine.')
param adminUsername string = 'azureuser'

@description('The admin password for the Virtual Machine.')
@secure()
param adminPassword string

@description('The name of the Log Analytics Workspace for VM Insights.')
param logAnalyticsWorkspaceName string = '${vmName}-laws'

@description('The name of the Data Collection Rule for VM Insights.')
param dataCollectionRulename string = '${vmName}-dcr'

@description('The name of the Linux AMA Agent extension for VM Insights.')
param linuxAMAAgentName string = '${vmName}-LinuxAMAAgent'

@description('The name of the Data Collection Rule Association for VM Insights.')
param dcrassociationName string = 'assoc-${vmName}-${dataCollectionRulename}'

@description('The name of the Recovery Services Vault for backup.')
param recoveryServicesVaultName string = '${vmName}-rsv'

@description('The retention period for Log Analytics data in days.')
param logAnalyticsRetentionInDays int = 30

@description('The name of the backup policy for the VM.')
param backupPolicyName string = '${vmName}-DailyBackupPolicy'

@description('The instant recovery point retention range in days.')
@minValue(1)
@maxValue(30)
param instantRpRetentionRangeInDays int = 7 

@description('The number of days to retain daily backup points.')
@minValue(1)
param dailyRetentionCount int = 30

// ====================================================================
// VARIABLES
// ====================================================================
var subnetAddressPrefix = '10.0.0.0/24'
var vnetAddressPrefix = '10.0.0.0/16'
var publicIPAllocationMethod = 'Static'
var publicIPSku = 'Standard'
var osDiskCreateOption = 'FromImage'
var imagePublisher = 'Canonical'
var imageOffer = '0001-com-ubuntu-server-jammy'
var imageSku = '22_04-lts-gen2'
var imageVersion = 'latest'
var backupFabric = 'Azure'
var protectionContainer = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
var protectedItem = 'vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'

// ====================================================================
// RESOURCES
// ====================================================================
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}


resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: publicIPName
  location: location
  sku: {
    name: publicIPSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
}


resource networkInterface 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
        }
      }
    ]
  }
}


resource virtualmachine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: osDiskCreateOption
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        diskSizeGB: 30 
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}


resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionInDays
  }
}


resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: dataCollectionRulename
  location: location
  properties: {
    dataSources: {
      performanceCounters: [
        {
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60

          counterSpecifiers: [
            '\\vminsights\\detailedmetrics'
          ]
          name: 'VMInsightsDetailedMetrics'
        }
      ]
      extensions: [
        {
          streams: [
            'Microsoft-ServiceMap'
          ]
          extensionName: 'VMInsightsExtension'
          extensionSettings:{}
          name:'DependencyAgentExtension'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logAnalyticsWorkspace.id
          name: 'LogAnalyticsWorkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [  
          'Microsoft-InsightsMetrics'
          'Microsoft-ServiceMap'
        ]
        destinations: [
            'LogAnalyticsWorkspace'
        ]
      }
    ]
  }
}


resource LinuxAMAAgent 'microsoft.compute/virtualMachines/extensions@2024-07-01' = {
  parent: virtualmachine
  name: linuxAMAAgentName
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.21'
    autoUpgradeMinorVersion: true
    settings: {
    }
  }
  dependsOn: [
    dataCollectionRule
  ]
}


resource DCRAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  scope: virtualmachine
  name: dcrassociationName
  properties: {
    description: 'Association of VM with VM Insights DCR'
    dataCollectionRuleId: dataCollectionRule.id
  }
  dependsOn: [
    LinuxAMAAgent
  ]
}


resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2025-02-01' = {
  name: recoveryServicesVaultName
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
  }
  sku: {
      name: 'RS0'
      tier: 'Standard'
    }
  }


resource vaultName_backupFabric_protectionContainer_protectedItem 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2025-02-01' = {
  name: '${recoveryServicesVaultName}/${backupFabric}/${protectionContainer}/${protectedItem}'
  location: location
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    sourceResourceId: virtualmachine.id
    policyId: backupPolicy.id
  }
}


resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2025-02-01' = {
  parent: recoveryServicesVault
  name: backupPolicyName
  properties: {
    backupManagementType: 'AzureIaasVM' 
    policyType: 'V2' 
    instantRPDetails: {}
    instantRpRetentionRangeInDays: instantRpRetentionRangeInDays
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule: {
        scheduleRunTimes: [
          '2025-07-31T22:00:00Z' 
        ]
      }
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2025-07-31T22:00:00Z'
        ]
        retentionDuration: {
          count: dailyRetentionCount
          durationType: 'Days'
        }
      }
    }
    tieringPolicy: {
      ArchivedRP: {
        tieringMode: 'DoNotTier'
        duration: 0
        durationType: 'Invalid'
      }
    }    
    timeZone: 'UTC'
    protectedItemsCount: 0
  }
}
