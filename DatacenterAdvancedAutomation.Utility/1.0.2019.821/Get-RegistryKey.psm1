Function
Get-RegistryKey
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
        [Microsoft.Win32.RegistryHive]
        $Hive = [Microsoft.Win32.RegistryHive]::LocalMachine
    ,
        [Parameter(
            Mandatory        = $True
        )]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory        = $False,
            ParameterSetName = 'Online'
        )]
        [System.String]
        [ValidateNotNullOrEmpty()]
        $ComputerName
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
        If
        (
            $ComputerName -and
            $ComputerName -ne $env:ComputerName
        )
        {
            $ComputerName = Resolve-dnsNameEx -Name $ComputerName
        }
        Else
        {
            $ComputerName = $env:ComputerName
        }

        $BaseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( $Hive, $ComputerName )

        If
        (
            $Path
        )
        {
          # Mount

            $Name = 'blah' + $Name
        }

        $Key     = $BaseKey.OpenSubKey( $Name )

        If
        (
            $Path
        )
        {
          # dismount
        }

        Return $Key
    }
}