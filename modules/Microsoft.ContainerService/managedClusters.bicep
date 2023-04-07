

param location string = resourceGroup().location
param tags object
param name string
param dnsPrefix string
param kubernetesVersion string 
param networkPlugin string
param enableRBAC bool 
param nodeResourceGroup string
param disableLocalAccounts bool 
param enablePrivateCluster bool 
param enableAzurePolicy bool 
param enableSecretStoreCSIDriver bool 
param vnetName string
param snetName string
param serviceCidr string
param dnsServiceIp string
param upgradeChannel string

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: snetName
  parent: vnet
}

resource managedClusters 'Microsoft.ContainerService/managedClusters@2022-06-01' = {
  location: location
  tags: tags
  name: name
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: enableRBAC
    dnsPrefix: dnsPrefix
    nodeResourceGroup: nodeResourceGroup
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {
          metricLabelsAllowlist: ''
          metricAnnotationsAllowList: ''
        }
      }
    }
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        enableAutoScaling: true
        minCount: 1
        maxCount: 3
        vmSize: 'Standard_DS2_v2'
        osType: 'Linux'
        storageProfile: 'ManagedDisks'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        maxPods: 70
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeLabels: {}
        nodeTaints: []
        enableNodePublicIP: false
        tags: {}
        vnetSubnetID: subnet.id
      }
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: networkPlugin
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIp
    }
    autoUpgradeProfile: {
      upgradeChannel: upgradeChannel
    }
    disableLocalAccounts: disableLocalAccounts
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
    }
    addonProfiles: {
      azurepolicy: {
        enabled: enableAzurePolicy
      }
      azureKeyvaultSecretsProvider: {
        enabled: enableSecretStoreCSIDriver
        config: {
          enableSecretRotation: 'false'
          rotationPollInterval: '2m'
        }
      }
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output clusterPrincipalId string = managedClusters.identity.principalId
