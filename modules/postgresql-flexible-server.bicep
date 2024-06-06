@description('Deploy a PostgreSQL flexible server with a private network configuration.')
param serverName string
param location string
param skuName string = 'Standard_B1ms'
param tier string = 'Burstable'
param storageSizeGB int = 32
param subnetId string
param privateDnsZoneId string
@secure()
param adminUsername string
param adminPass string


resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2021-06-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: tier
  }
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPass
    version: '13'
    storage: {
      storageSizeGB: storageSizeGB
    }
    network: {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneArmResourceId: privateDnsZoneId
    }
  }
}

output postgresqlServerName string = postgresqlServer.name
output postgresqlServerFqdn string = postgresqlServer.properties.fullyQualifiedDomainName
