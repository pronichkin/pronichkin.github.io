Set-StrictMode -Version 'Latest'

Function
Get-scvmHostEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.HostGroup[]]
        $HostGroup
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.SwitchParameter]
        $Recurse
    )

    Process
    {
        $vmHost = [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]::new()

        $HostGroup | ForEach-Object -Process {

            $HostGroupCurrent = $psItem

            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHostCurrent =
                Get-scvmHost -vmHostGroup $HostGroupCurrent

            If
            (
                $vmHostCurrent
            )
            {
                $vmHost.addRange( $vmHostCurrent )
            }

            If
            (
                $Recurse
            )
            {
                While
                (
                    Get-scvmHostGroup -ParentHostGroup $HostGroupCurrent
                )
                {
                    Get-scvmHostGroup -ParentHostGroup $HostGroupCurrent | ForEach-Object {

                        $HostGroupCurrent = $psItem

                        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHostCurrent =
                            Get-scvmHost -vmHostGroup $HostGroupCurrent

                        If
                        (
                            $vmHostCurrent
                        )
                        {
                            $vmHost.addRange( $vmHostCurrent )
                        }
                    }
                }
            }
        }

        Return $vmHost
    }
}