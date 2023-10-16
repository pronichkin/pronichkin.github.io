#requires -RunAsAdministrator

Set-StrictMode -Version 'Latest'

Function
Mount-RegistryKey
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [Microsoft.Win32.RegistryKey]
    )]

    param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]        
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.ValidateScriptAttribute(
            { $psItem.Exists }
        )]
        [System.Management.Automation.AliasAttribute(
            'Key'
        )]
        [System.Io.FileInfo]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            ValueFromPipeline = $false
        )]        
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [Microsoft.Win32.RegistryHive]
        $Hive = [Microsoft.Win32.RegistryHive]::LocalMachine
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            ValueFromPipeline = $false
        )]        
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
        $Name = [System.IO.Path]::GetRandomFileName()
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.SwitchParameter]
        $ReadOnly
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
        $message = "Mounting registry key `“$( $InputObject.FullName )`”"
        Write-Message -Channel Debug -Message $message

        if
        (
            $ReadOnly
        )
        {
            $Path = Join-Path -Path $env:Temp -ChildPath $Name

            $CopyParam = @{

                Path        = $InputObject.FullName
                Destination = $Path
                PassThru    = $True
            }
            $InputObject = Copy-Item @CopyParam

            $message = "read-only from `“$( $InputObject.FullName )`”"
            Write-Message -Channel Debug -Message $message
        }        

        $param = @(
            [System.Int32]  $Hive
            [System.String] $Name
            [System.String] $InputObject.FullName
        )

        if
        (        
            $WinReg::RegLoadKeyW.Invoke( $param )
        )
        {
            throw [System.ComponentModel.Win32Exception]::new()
        }
        else        
        {
            $key = $Name | Get-RegistryKey -Hive $Hive

            $Message = "mounted to `“$($key.name)`”"
            Write-Message -Channel Debug -Message $Message

            return $key
        }        
    }

    end
    {}
}