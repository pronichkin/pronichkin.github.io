#Requires -RunAsAdministrator

Set-StrictMode -Version 'Latest'

Function
Mount-RegistryHive
{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 0
        )]
        [System.Io.FileInfo]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            { $psItem.Exists }
        )]
        $Hive
    )

    Process
    {
        [System.Void]( Set-TokenPrivilege -Privilege 'SeBackupPrivilege'  )
        [System.Void]( Set-TokenPrivilege -Privilege 'SeRestorePrivilege' )

        $mountKeyName = [System.IO.Path]::GetRandomFileName()
        $HiveKey      = [Microsoft.Win32.RegistryHive]::LocalMachine

        $TypePath = Join-Path -Path $psScriptRoot -ChildPath 'RegistryHive.cs'

        $TypeParam = @{

          # MemberDefinition $Definition
            Name      = 'ClassLoad'
            Namespace = 'Win32Functions'
            PassThru  = $True
            Verbose   = $False
        }

        $Reg = Add-Type -

        $Result = $Reg::RegLoadKey( $HiveKey, $mountKeyName, $Hive )

    }
    Catch
    {
        Throw
    }

  # Set a global variable containing the name of the mounted registry key
  # so we can unmount it if there's an error.
    $global:mountedHive = $mountKey

    return $mountKey
}