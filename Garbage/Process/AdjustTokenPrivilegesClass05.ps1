    Import-Module -Name 'DatacenterAdvancedAutomation.Process' -Force

    $VerbosePreference     = [System.Management.Automation.ActionPreference]::Continue
    $DebugPreference       = [System.Management.Automation.ActionPreference]::Continue
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    Set-StrictMode -Version  'Latest'

    $Name = 'SeIncreaseQuotaPrivilege'  # Adjust memory quotas for a process
  # $Name = 'SeSecurityPrivilege'       # Manage auditing and security log
  # $Name = 'SeTakeOwnershipPrivilege'  # Take ownership of files or other objects

    whoami.exe /priv | findstr.exe /i $name

    Get-Privilege -Name $Name | Set-TokenPrivilege  # -Attribute SE_PRIVILEGE_DISABLED

    whoami.exe /priv | findstr.exe /i $name