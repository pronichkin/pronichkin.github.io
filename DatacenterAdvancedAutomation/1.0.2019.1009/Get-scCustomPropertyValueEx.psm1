Set-StrictMode -Version 'Latest'

Function
Get-scCustomPropertyValueEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.HostGroup]
        $HostGroup
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.CustomProperty]
        $CustomProperty
    )

    Process
    {
        $PropertyValueParam = @{

            CustomProperty = $CustomProperty
            InputObject    = $HostGroup
        }
        $PropertyValue = Get-scCustomPropertyValue @PropertyValueParam

        While
        (
            [System.String]::IsNullOrWhiteSpace( $PropertyValue )
        )
        {
            $HostGroup = $HostGroup.ParentHostGroup

            $PropertyValueParam = @{

                CustomProperty = $CustomProperty
                InputObject    = $HostGroup
            }
            $PropertyValue = Get-scCustomPropertyValue @PropertyValueParam
        }

        Return $PropertyValue
    }
}