Set-StrictMode -Version 'Latest'

Function
Test-PathEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $cimSession
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    Process
    {
        $InstanceParam = @{

            ClassName  = 'cim_DataFile'
            Filter     = "Name='$($Path.Replace( '\', '\\' ))'"            
            Verbose    = $False
        }

        If
        (
            $cimSession
        )
        {
            $InstanceParam.Add( 'cimSession', $cimSession )
        }

        If
        (
            Get-CimInstance @InstanceParam
        )
        {
            $Return = [System.Boolean]( Get-CimInstance @InstanceParam )
        }
        Else
        {
            $InstanceParam.ClassName = 'cim_Directory'

            $Return = [System.Boolean]( Get-CimInstance @InstanceParam )
        }
        
        Return $Return
    }
}