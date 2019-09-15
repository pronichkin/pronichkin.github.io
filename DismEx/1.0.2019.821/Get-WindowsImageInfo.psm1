Function
Get-WindowsImageInfo
{
    [cmdletBinding(
        DefaultParametersetName = 'Online'
    )]

    [outputType([Microsoft.Win32.RegistryKey])]

    Param(
        [Parameter(
            Mandatory        = $False,
            ParameterSetName = 'Online'
        )]
        [System.String]
        [ValidateNotNullOrEmpty()]
        $ComputerName = $env:ComputerName
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Offline'
        )]
        [System.IO.DirectoryInfo]
        $Path
    )

    Process
    {
        $RegistryKeyParam = @{
            Name = 'Software\Microsoft\Windows NT\CurrentVersion'
        }

        If
        (
            $ComputerName
        )
        {
            $RegistryKeyParam.Add( 'ComputerName', $ComputerName )
        }
        ElseIf
        (
            $Path
        )
        {
            $RegistryKeyParam.Add( 'Path', $Path )
        }

        Return Get-RegistryKey @RegistryKeyParam
    }
}