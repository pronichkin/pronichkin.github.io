Set-StrictMode -Version 'Latest'

Function
Get-vmFromVirtualMachine
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]
        $VirtualMachine
    )

    Begin
    {
      # Ensure we have the correct Hyper-V module loaded

        Test-ModuleEx
        
        $vm = [System.Collections.Generic.List[Microsoft.HyperV.PowerShell.VirtualMachine]]::new()

        If
        (
            $VirtualMachine[0].ServerConnection.ForOnBehalfOf
        )
        {
          # VMM connection in “For On Behalf Of” mode does not provide access
          # to Fabric-level properties—such as Host name. Hence re-establishing
          # connection to VMM server in regular (admin) mode and re-obtaining
          # VM object

            $vmmServer = Get-scvmmServerEx -vmmServer $VirtualMachine[0].ServerConnection

            $VirtualMachine = $VirtualMachine | ForEach-Object -Process {
            
                Get-scVirtualMachine -vmmServer $vmmServer -ID $psItem.ID
            }
        }
    }

    Process
    {
        $VirtualMachine | ForEach-Object -Process {

            If
            (
                $psItem.IsHighlyAvailable
            )
            {
                $Cluster = Get-Cluster -Name $psItem.HostName

                $ClusterGroupParam = @{

                    InputObject = $Cluster
                    VMId        = $psItem.VMId
                }
                $ClusterGroup = Get-ClusterGroup @ClusterGroupParam

                $vmParam = @{

                    ClusterObject = $ClusterGroup
                }
            }
            Else
            {
                $Session = New-cimSessionEx -Name $psItem.HostName

                $vmParam = @{

                    CimSession = $Session
                    Id         = $psItem.VMId
                }
            }

            $vm.Add( ( Hyper-V\Get-VM @vmParam ) )
        }
    }

    End
    {
        Return ,$vm
    }
}