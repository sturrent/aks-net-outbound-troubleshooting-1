param privateDnsZoneName string
param privateDnsZoneLinkName string
param aksVnetId string
param dbVnetId string
param recordName string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'

  resource link 'virtualNetworkLinks' = {
    name: privateDnsZoneLinkName
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: { id: aksVnetId }
    }
  }

  resource link2 'virtualNetworkLinks' = {
    name: 'db-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: { id: dbVnetId }
    }
  }

  resource aRecord 'A' = {
    name: recordName
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: '10.0.0.4'
        }
      ]
    }
  }
}

output privateDnsZoneId string = privateDnsZone.id
