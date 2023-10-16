Set-StrictMode -Version 'Latest'

Function
Get-RegistryKey
{
    [System.Management.Automation.CmdletBindingAttribute(
        DefaultParametersetName = 'Online'
    )]

    [System.Management.Automation.OutputTypeAttribute(
        [Microsoft.Win32.RegistryKey]
    )]

    param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.AliasAttribute(
            'Name'
        )]
        [System.String]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory        = $false
        )]
        [Microsoft.Win32.RegistryHive]
        $Hive = [Microsoft.Win32.RegistryHive]::LocalMachine
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory        = $false,
            ParameterSetName = 'Online'
        )]        
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
        $ComputerName
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory        = $true,
            ParameterSetName = 'Offline'
        )]
        [System.IO.DirectoryInfo]
        $Path
    )

    process
    {
        if
        (
            $ComputerName -and
            $ComputerName -ne $env:ComputerName
        )
        {
            $ComputerName = Resolve-dnsNameEx -Name $ComputerName

          # https://learn.microsoft.com/dotnet/api/microsoft.win32.registrykey.openremotebasekey

            $param = @(
                $Hive          # HKEY to open, from the RegistryHive enumeration
                $ComputerName  # remote machine
            )
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey.Invoke( $param )
        }
        else
        {
          # https://learn.microsoft.com/dotnet/api/microsoft.win32.registrykey.openbasekey

            $param = @(
                $Hive                                     # HKEY to open
                [Microsoft.Win32.RegistryView]::Default   # registry view to use
            )
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey.Invoke( $param )
        }        

     <# not implemented yet

        if
        (
            $Path
        )
        {
          # Mount

            $Name = 'blah' + $Name
        }  #>

        $key     = $baseKey.OpenSubKey( $InputObject )

     <# if
        (
            $Path
        )
        {
          # dismount
        }  #>

        return $key
    }
}