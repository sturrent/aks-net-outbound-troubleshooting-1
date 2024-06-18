targetScope = 'subscription'

param location string = 'eastus2'
param userName string = 'lab1'
param resourceName string = 'workbench'
param zoneName string = 'postgresdb1-workbench-lab1.private.postgres.database.azure.com'
param recordName string = 'db1'

var postgresqlName = 'postgresql-${userName}-${uniqueString(subscription().id)}'
var aksResourceGroupName = 'aks-${resourceName}-${userName}-rg'
var vnetResourceGroupName = 'vnet-${resourceName}-${userName}-rg'
var dbResourceGroupName = 'db-${resourceName}-${userName}-rg'
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

module aksvnet './modules/aks-vnet.bicep' = {
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

module dbvnet './modules/db-vnet.bicep' = {
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

module privatednszone './modules/private-dns-zone.bicep' = {
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

module vnetpeeringdb './modules/vnetpeering.bicep' = {
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

module vnetpeeringaks './modules/vnetpeering.bicep' = {
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

module postgresqlModule './modules/postgresql-flexible-server.bicep' = {
  scope: dbrg
  name: 'postgresqlModule'
  dependsOn: [
    dbvnet, privatednszone
  ]
  params: {
    serverName: postgresqlName
    location: location
    adminUsername: 'admindb'
    adminPass: 'T3mp0r4l'
    subnetId: dbvnet.outputs.dbsubnet
    privateDnsZoneId: privatednszone.outputs.privateDnsZoneId
  }
}

module akscluster './modules/aks-cluster.bicep' = {
  name: resourceName
  scope: clusterrg
  dependsOn: [ aksvnet, privatednszone ]
  params: {
    location: location
    clusterName: 'aks-${resourceName}'
    aksSubnetId: aksvnet.outputs.akssubnet
  }
}

module roleAuthorization './modules/aks-auth.bicep' = {
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

module kubernetes './modules/workloads.bicep' = {
  name: 'buildbicep-deploy'
  scope: clusterrg
  dependsOn: [
    akscluster
  ]
  params: {
    kubeConfig: akscluster.outputs.kubeConfig
  }
}
