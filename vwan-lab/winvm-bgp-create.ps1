param(
       [string]$local_ip,
       [string]$local_bgp,
       [string]$peer_1,
       [string]$peer_2
   )

# Install required Windows features
Install-WindowsFeature RemoteAccess 
Install-WindowsFeature RSAT-RemoteAccess-PowerShell 
Install-WindowsFeature Routing
Install-RemoteAccess -VpnType RoutingOnly

# Import the custom BGP configuration module
Import-Module -Name BGPConfigModule

# Configure BGP & Router ID on the Windows Server
Add-BgpRouter -BgpIdentifier $local_ip -LocalASN $SG_BGP

# Configure Azure Route Server as a BGP Peer
Add-BgpPeer -LocalIPAddress $local_ip -PeerIPAddress $local_bgp -PeerASN 65515 -Name 'RS_IP1'
Add-BgpPeer -LocalIPAddress $local_ip -PeerIPAddress $peer_2 -PeerASN 65515 -Name 'RS_IP2'

# Originate and announce BGP routes
Add-BgpCustomRoute -Network '0.0.0.0/1'
Add-BgpCustomRoute -Network '128.0.0.0/1'
