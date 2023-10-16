#requires -RunAsAdministrator

Set-StrictMode -Version 'Latest'

Function
Dismount-RegistryKey
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Void]
    )]

    param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]        
        [ValidateNotNullOrEmpty()]
        [Microsoft.Win32.RegistryKey]
        $InputObject
    )

    begin
    {
        [System.Void](
            @(
                'SeBackupPrivilege'
                'SeRestorePrivilege'
            ) | Get-Privilege | Set-TokenPrivilege
        )

        $WinReg = Add-TypeEx -InputObject 'WinReg'
    }

    process
    {
        $split = $InputObject.Name.Split( [System.IO.Path]::DirectorySeparatorChar )

      # https://stackoverflow.com/questions/58510869/c-sharp-get-basekey-from-registrykey
        switch
        (
            $split[0]
        )
        {
            'HKEY_LOCAL_MACHINE'
            {
                $hive = [Microsoft.Win32.RegistryHive]::LocalMachine
            }

            'HKEY_USERS'
            {
                $hive = [Microsoft.Win32.RegistryHive]::Users
            }

            default
            {
                throw "unknown base key name: $psItem"
            }
        }

        $name = $split[1]

        $message = "closing handle to `“$($InputObject.Name)`”"
        Write-Message -Channel Debug -Message $message

        $InputObject.Close()

        $param = @(
            [System.Int32]  $hive
            [System.String] $name
        )

        if
        (        
            $WinReg::RegUnLoadKeyW.Invoke( $param )
        )
        {
            throw [System.ComponentModel.Win32Exception]::new()
        }
        else
        {
            $message = "dismounted `“$name`”"
            Write-Message -Channel Debug -Message $message

            $file = Get-ChildItem -Path $env:temp -Filter $name

            if
            (
                $file
            )
            {
                $message = "removing remporary file `“$($file.FullName)`”"
                Write-Message -Channel Debug -Message $message

                Remove-Item -Path $file.FullName
            }

            return $null
        }
    }

    end
    {}
}