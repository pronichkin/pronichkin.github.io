Function
Get-scSubnetVlanEx
{
    [cmdletBinding()]

    Param(

        [parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.LogicalNetwork]
        $LogicalNetwork
    ,
        [parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.HostGroup]
        $HostGroup
    )

    Process
    {
        $LogicalNetworkDefinitionParam = @{
                
            LogicalNetwork = $LogicalNetwork
            vmHostGroup    = $HostGroup
        }                
        $LogicalNetworkDefinition =
            Get-scLogicalNetworkDefinition @LogicalNetworkDefinitionParam
                
        $SubnetVlan = $LogicalNetworkDefinition.SubnetVLans

        Return $SubnetVlan
    }
}