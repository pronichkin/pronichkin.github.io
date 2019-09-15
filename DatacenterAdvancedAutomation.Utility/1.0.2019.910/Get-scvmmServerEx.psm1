<#
    Obtain Vmm Management Server object, if available
#>

Set-StrictMode -Version 'Latest'

Function
Get-scvmmServerEx
{
        [cmdletBinding()]

        Param(

            [parameter(
                Mandatory = $False
            )]
            [System.String]
            $Name
        ,
            [parameter(
                Mandatory = $False
            )]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer
        ,
            [parameter(
                Mandatory = $False
            )]
            [System.Management.Automation.SwitchParameter]
            $ForOnBehalfOf
        )

    Process
    {
      # Write-Debug -Message "Entering Get-scvmmServerEx for $vmmServerName"

      # Try to determine whether we have Vmm server already on the network

        If
        (
            $vmmServer
        )
        {
            $vmmServerAddress = $vmmServer.FullyQualifiedDomainName
        }
        Else
        {
            $vmmServerAddress = Resolve-DnsNameEx -Name $Name -Wait:$False
        }

      # Determine whether we have module installed

        $Module = Import-ModuleEx -Name 'VirtualMachineManager'

      # If both conditions are true, obtain the object

        If
        (
            $vmmServerAddress -and $Module
        )
        {
            $ServerParam = @{
            
                ComputerName  = $vmmServerAddress
                ForOnBehalfOf = $ForOnBehalfOf
            }
            Return Get-scvmmServer @ServerParam
        }

      # Write-Verbose -Message "Exiting  Get-scvmmServerEx for $vmmServerName"

      # Return $vmmServer
    }
}