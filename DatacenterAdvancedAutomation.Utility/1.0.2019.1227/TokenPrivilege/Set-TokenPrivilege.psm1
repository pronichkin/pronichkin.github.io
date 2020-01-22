<#
   #Requires -RunAsAdministrator
#>

<#
    The privilege to adjust. This set is taken from
    https://msdn.microsoft.com/library/bb530716
    https://docs.microsoft.com/windows/win32/secauthz/privilege-constants
#>

Set-StrictMode -Version 'Latest'

Enum
Privilege
{
    SeAssignPrimaryTokenPrivilege
    SeAuditPrivilege
    SeBackupPrivilege
    SeChangeNotifyPrivilege
    SeCreateGlobalPrivilege
    SeCreatePagefilePrivilege
    SeCreatePermanentPrivilege
    SeCreateSymbolicLinkPrivilege
    SeCreateTokenPrivilege
    SeDebugPrivilege
    SeEnableDelegationPrivilege
    SeImpersonatePrivilege
    SeIncreaseBasePriorityPrivilege
    SeIncreaseQuotaPrivilege
    SeIncreaseWorkingSetPrivilege
    SeLoadDriverPrivilege
    SeLockMemoryPrivilege
    SeMachineAccountPrivilege
    SeManageVolumePrivilege
    SeProfileSingleProcessPrivilege
    SeRelabelPrivilege
    SeRemoteShutdownPrivilege
    SeRestorePrivilege
    SeSecurityPrivilege
    SeShutdownPrivilege
    SeSyncAgentPrivilege
    SeSystemEnvironmentPrivilege
    SeSystemProfilePrivilege
    SeSystemtimePrivilege
    SeTakeOwnershipPrivilege
    SeTcbPrivilege
    SeTimeZonePrivilege
    SeTrustedCredManAccessPrivilege
    SeUndockPrivilege
    SeUnsolicitedInputPrivilege
}

<#
    This is required for renewed “Mount-RegistryHive” and “Dismount-RegistryHive”
    functions using Windows API. Code borrowed from and formatted for readability
    http://www.leeholmes.com/blog/2010/09/24/adjusting-token-privileges-in-powershell/
#>

Function
Set-TokenPrivilege
{
    [CmdletBinding(
      # ConfirmImpact           = <String>,
      # DefaultParameterSetName = <String>,
      # HelpURI                 = <URI>,
      # SupportsPaging          = <Boolean>,
      # SupportsShouldProcess   = <Boolean>,
        PositionalBinding       = $False
    )]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [Privilege]
        $Privilege
    ,
      # The process on which to adjust the privilege. Defaults to the current
      # process
        [Parameter(
            Mandatory = $False
        )]
        [System.Int32]
        $ProcessId = $pid
    ,
      # Switch to disable the privilege, rather than enable it
        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Disable
    )

    Process
    {
        If
        (
            $Disable
        )
        {
            $Message = "    Disabling `“$Privilege`”"
        }
        Else
        {
            $Message = "    Enabling `“$Privilege`”"
        }
        Write-Debug -Message $Message

        $PathParam = @{

            Path      = $psScriptRoot
            ChildPath = 'AdjustTokenPrivilege.cs'
        }
        $TypePath = Join-Path @PathParam

        $ProcessHandle = ( Get-Process -id $ProcessId ).Handle

        $TypeParam = @{

          # TypeDefinition = $Definition
            Path           = $TypePath
            Verbose        = $False
            Debug          = $False
          # PassThru       = $True
        }
        Add-Type @TypeParam

      # Assigning result of previous command to a variable (with “PassThru”) is
      # not very helpful because it will output an array of two objects. Hence
      # we have to call the class by its name instead of relying on the
      # variable.

        $PrivilegeParam = @(

            [System.Int64]   $ProcessHandle
            [System.String]  $Privilege
            [System.Boolean] $Disable
        )
        
        Return [AdjustTokenPrivilege]::EnablePrivilege.Invoke( $PrivilegeParam )
    }
}