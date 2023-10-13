Set-StrictMode -Version 'Latest'

Function
New-cimSessionEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name
    )

    $Session = $Name | ForEach-Object -Process {

        If
        (
            $psItem.Contains( '.' )
        )
        {
            $NameCurrent = $psItem.Split( '.' )[0]
        }
        Else
        {
            $NameCurrent = $psItem
        }

        $Address = Resolve-dnsNameEx -Name $NameCurrent

        $SessionParam = @{

            ComputerName  = $Address
            Verbose       = $False
        }

      # Check if there's a port-specific SPN

        $Spn = "	http/$($Address):5985"

        If
        (
            SetSpn.exe -l $NameCurrent | Where-Object -FilterScript { $psItem -eq $Spn }
        )
        {
            $Option = New-cimSessionOption -EncodePortInServicePrincipalName

            $SessionParam.Add( 'SessionOption', $Option )
        }

        New-cimSession @SessionParam
    }

    Return $Session 
}