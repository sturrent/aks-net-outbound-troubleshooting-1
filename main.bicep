targetScope = 'subscription'

param location string = 'eastus2'
param resourcePrefix string = 'aks-work-lab1'
param zoneName string = 'postgresdb1-workbench-lab1.private.postgres.database.azure.com'
param recordName string = 'db1'

var aksResourceGroupName = '${resourcePrefix}-rg'
var vnetResourceGroupName = 'vnet-${resourcePrefix}-rg'
var dbResourceGroupName = 'workgroup-db-lab1-rg'
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource clusterrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: aksResourceGroupName
  location: location
}

resource vnetrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: vnetResourceGroupName
  location: location
}

resource dbrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: dbResourceGroupName
  location: location
}

module aksvnet './aks-vnet.bicep' = {
  name: 'aks-vnet'
  scope: vnetrg
  params: {
    location: location
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '172.16.0.0/24'
        }
      } 
    ]
    vnetName: 'aks-vnet'
    vvnetPreffix:  [
      '172.16.0.0/16'
    ]
  }
}

module dbvnet './db-vnet.bicep' = {
  name: 'db-vnet'
  scope: dbrg
  params: {
    location: location
    subnets: [
      {
        name: 'db-subnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [
            {
                name: 'db-subnet-delegation'
                properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
                }
            }]
        }
      } 
    ]
    vnetName: 'db-vnet'
    vvnetPreffix:  [
      '10.0.0.0/16'
    ]
  }
}

module privatednszone './private-dns-zone.bicep' = {
  name: 'private-dns-zone'
  scope: dbrg
  dependsOn: [
    dbvnet, aksvnet
  ]
  params: {
    privateDnsZoneName: zoneName
    recordName: recordName
    privateDnsZoneLinkName: 'db-vnet-link'
    aksVnetId: aksvnet.outputs.aksVnetId
    dbVnetId: dbvnet.outputs.dbVnetId
  }
}

module vnetpeeringdb 'vnetpeering.bicep' = {
  scope: dbrg
  name: 'vnetpeering'
  params: {
    peeringName: 'db-to-aks'
    vnetName: dbvnet.outputs.vnetName
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: aksvnet.outputs.aksVnetId
      }
    }    
  }
}

module vnetpeeringaks 'vnetpeering.bicep' = {
  scope: vnetrg
  name: 'vnetpeering2'
  params: {
    peeringName: 'aks-to-db'
    vnetName: aksvnet.outputs.vnetName
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: dbvnet.outputs.dbVnetId
      }
    }    
  }
}

module postgresqlModule 'postgresql-flexible-server.bicep' = {
  scope: dbrg
  name: 'postgresql-flexible-server'
  dependsOn: [
    dbvnet, privatednszone
  ]
  params: {
    serverName: 'postgresdb1-workbench'
    location: location
    adminUsername: 'admindb'
    adminPass: 'T3mp0r4l'
    subnetId: dbvnet.outputs.dbsubnet
    privateDnsZoneId: privatednszone.outputs.privateDnsZoneId
  }
}

module akscluster './aks-cluster.bicep' = {
  name: resourcePrefix
  scope: clusterrg
  dependsOn: [ aksvnet, privatednszone ]
  params: {
    location: location
    clusterName: resourcePrefix
    aksSubnetId: aksvnet.outputs.akssubnet
  }
}

module roleAuthorization 'aks-auth.bicep' = {
  name: 'roleAuthorization'
  scope: vnetrg
  dependsOn: [
    akscluster
  ]
  params: {
      principalId: akscluster.outputs.aks_principal_id
      roleDefinition: contributorRoleId
  }
}

module kubernetes './workloads.bicep' = {
  name: 'buildbicep-deploy'
  scope: clusterrg
  dependsOn: [
    akscluster
  ]
  params: {
    kubeConfig: akscluster.outputs.kubeConfig
  }
}
