Set-StrictMode -Version 'Latest'

Function
Get-scVirtualMachineFromVM
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[Microsoft.HyperV.PowerShell.VirtualMachine]]
        $vm
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer
    )

    Begin
    {}

    Process
    {
        [System.Collections.Generic.List[Microsoft.SystemCenter.VirtualMachineManager.VM]]$VirtualMachine = 
            Get-scVirtualMachine -vmmServer $vmmServer | Where-Object -FilterScript {
                $PSItem.VMId -in $vm.id
            }
    }

    End
    {
        Return ,$VirtualMachine
    }
}