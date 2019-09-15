#Requires -RunAsAdministrator

Set-StrictMode -Version 'Latest'

Function
Dismount-RegistryHive
{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 0
        )]
        [string]
        [ValidateNotNullOrEmpty()]
        $Hive
    )

    Process
    {
        [System.Void]( Set-TokenPrivilege -Privilege 'SeBackupPrivilege'  )
        [System.Void]( Set-TokenPrivilege -Privilege 'SeRestorePrivilege' )



        $TypePath = Join-Path -Path $psScriptRoot -ChildPath 'RegistryHive.cs'
        

        $HKLM = 0x80000002

        $Reg = Add-Type -MemberDefinition $Definition -Name "ClassUnload" -Namespace "Win32Functions" -PassThru -Verbose:$False

        $Result = $Reg::RegUnLoadKey( $HKLM, $Hive )

    }
    Catch
    {
        Throw
    }

    Return $null
}