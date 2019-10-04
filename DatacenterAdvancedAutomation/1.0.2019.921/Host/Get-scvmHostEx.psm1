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
        $vmHostGroup
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

        $vmHostGroup | ForEach-Object -Process {

            $HostGroup = $psItem

            [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHostCurrent =
                Get-scvmHost -vmHostGroup $HostGroup

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
                    Get-scvmHostGroup -ParentHostGroup $HostGroup
                )
                {
                    Get-scvmHostGroup -ParentHostGroup $HostGroup | ForEach-Object {

                        $HostGroup = $psItem

                        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.Host]]$vmHostCurrent =
                            Get-scvmHost -vmHostGroup $HostGroup

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