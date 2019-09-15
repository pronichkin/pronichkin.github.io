Function
Get-scCodeIntegrityPolicyEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Host]
        $vmHost
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $Session
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Manufacturer
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Model
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        $vmmServer
    )

    Process
    {
        If
        (
            $vmHost
        )
        {
            $Session   = New-cimSessionEx -Name $vmHost.Name
            $vmmServer = $vmHost.ServerConnection
        }

        If
        (
            $Session
        )
        {
            $System = Get-ComputerSystem -Session $Session

            $Manufacturer = $System.Manufacturer
            $Model        = $System.Model
        }

        $CodeIntegrityPolicyName = "$Manufacturer $Model"

        $CodeIntegrityPolicyVersion = Get-scCodeIntegrityPolicy -vmmServer $vmmServer |
            Where-Object -FilterScript { $psItem.Name -like "$CodeIntegrityPolicyName*" } |
                ForEach-Object -Process { [System.Version]$psItem.Name.Split( '—' )[1] } |        
                    Sort-Object -Unique | Select-Object -Last 1

        If
        (
            $CodeIntegrityPolicyVersion
        )
        {
            $CodeIntegrityPolicyParam = @{

                vmmServer = $vmmServer
                Name      = "$CodeIntegrityPolicyName — $($CodeIntegrityPolicyVersion.ToString())"
            }
            Get-scCodeIntegrityPolicy @CodeIntegrityPolicyParam
        }
    }
}