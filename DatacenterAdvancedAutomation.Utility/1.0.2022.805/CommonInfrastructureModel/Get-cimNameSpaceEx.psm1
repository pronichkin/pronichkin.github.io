Set-StrictMode -Version 'Latest'

Function
Get-cimNameSpaceEx
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[Microsoft.Management.Infrastructure.CimSession]]
        $cimSession = ( New-cimSession -Verbose:$False )
    )

    Process
    {
        If
        (
            $Name.Contains( '%' )
        )
        {
            $Filter = "Name like '$Name'"
        }
        Else
        {
            $Filter = "Name = '$Name'"
        }

        [System.Collections.Generic.List[Microsoft.Management.Infrastructure.CimInstance]](
        
            $cimSession | ForEach-Object -Process {

                $InstanceParam = @{

                    NameSpace   = $Path
                    ClassName   = '__NameSpace'
                    Filter      = $Filter
                    CimSession  = $psItem
                    Verbose     = $False
                }                
                Get-CimInstance @InstanceParam
            }
        )
    }
}