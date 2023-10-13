Set-StrictMode -Version 'Latest'

Function
Get-ComputerSystem
{
    [cmdletBinding()]

    [outputType([Microsoft.Management.Infrastructure.CimInstance])]

    Param(
        [Parameter()]
        [Microsoft.Management.Infrastructure.CimSession]
        [ValidateNotNullOrEmpty()]
        $Session
    )

    Process
    {
        $InstanceParam = @{
            ClassName = 'win32_ComputerSystem'
            Verbose   = $False
        }

        If
        (
            $Session
        )
        {
            $InstanceParam.Add( 'CimSession', $Session )
        }

        Return Get-CimInstance @InstanceParam
    }
}