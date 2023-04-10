$net = @{
    Name = 'vnet-mngmt'
    ResourceGroupName = 'rg-mngmnt'
}
$vnet = Get-AzVirtualNetwork @net

$sub = @{
    Name = 'snet-plinks'
    VirtualNetwork = $vnet
    AddressPrefix = '10.0.1.64/26'
    PrivateEndpointNetworkPoliciesFlag = 'RouteTableEnabled'  # Can be either 'Disabled', 'NetworkSecurityGroupEnabled', 'RouteTableEnabled', or 'Enabled'
}
Set-AzVirtualNetworkSubnetConfig @sub

$vnet | Set-AzVirtualNetwork