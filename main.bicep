param location string = resourceGroup().location

param vmName string = 'TestVM'
param nicName string = 'TestVMNIC'
param vnetName string = 'TestVMVNet'
param subnetName string = 'TestVMSubnet'
param publicIPName string = 'TestVMPIP'

param vmSize string = 'Standard_D2s_v3'

param adminUsername string = 'azureuser'
@secure()
param adminPassword string

param logAnalyticsWorkspaceName string = 'TestVMLAWS'
param dataCollectionRulename string = 'TestVMDataCollectionRule'
param recoveryServicesVaultName string = 'TestVMRecoveryVault'

var backupPolicyName = 'DailyBackupPolicy'
var backupFabric = 'Azure'
var protectionContainer = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
var protectedItem = 'vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
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
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
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
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
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
  name: '${vmName}-nsg'
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
    retentionInDays: 30
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
  name: '${vmName}-LinuxAMAAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.21'
    autoUpgradeMinorVersion: true
    settings: {
    }
  }
}

resource DCRAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  scope: virtualmachine
  name: 'assoc-${vmName}-${dataCollectionRulename}'
  properties: {
    description: 'Association of VM with VM Insights DCR'
    dataCollectionRuleId: dataCollectionRule.id
  }
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
  location: location
  name: backupPolicyName
  properties: {
    backupManagementType: 'AzureIaasVM' // Required for Azure VM backup
    policyType: 'V2' // Recommended for modern features
    instantRpRetentionRangeInDays: 30
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule: {
        scheduleRunTimes: [
          '22:00:00Z' // Corrected: Just the time with UTC designator
        ]
      }
    }
    retentionPolicy: {
      retentionPolicyType: 'SimpleRetentionPolicy'
      retentionDuration: {
        count: 7
        durationType: 'Days'
      }
    }
    timeZone: 'UTC' // Adjust as needed
    instantRPDetails: {
      azureBackupRGNamePrefix: 'BackupRG'
      azureBackupRGNameSuffix: '2025'
    }
  }
}
