 #requires -RunAsAdministrator 
 
 <# 
    Import-Module and the #requires statement only import the module functions,
    aliases, and variables, as defined by the module. Classes are not imported.
    The using module command imports the module and also loads the class
    definitions

    https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_using
  #>

using module '.\PrivilegeAttribute.psm1'

Set-StrictMode -Version 'Latest'

<#
   .Synopsis
    Change state of a privilege for a process

   .Description
    Change state (that is, Enabled or Disabled) of a privilege for a process. It
    can be needed for operations such as loading registry hives. This is
    basically a wrapper for Win32 “Adjust Token Privileges” function found in
    Advapi32.dll

   .Example
    Get-Privilege -Name 'SeSecurityPrivilege' | Set-TokenPrivilege

   .Link
    https://docs.microsoft.com/windows/win32/api/securitybaseapi/nf-securitybaseapi-adjusttokenprivileges

   .Notes
    This is a makeover of `Set-TokenPrivilege.ps1` by Lee Holmes
    https://www.leeholmes.com/adjusting-token-privileges-in-powershell
#>

Function
Set-TokenPrivilege
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Void]
    )]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False            
        )]
        [System.IntPtr]
     <# Process token (use `Get-ProcessToken` to obtain)
        Default is current process  #>
        $Token     = ( Get-ProcessToken -Access Query, AdjustPrivileges )
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.AliasAttribute(
            'Privilege'
        )]
        [System.Int64]
     <# Privilege LUID (use `Get-Privilege` to obtain)  #>
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]
        [PrivilegeAttribute]
     <# Privilege attribute (e.g., Enabled or Disabled)
        Default is Enabled  #>
        $Attribute = [PrivilegeAttribute]::SE_PRIVILEGE_ENABLED
    )

    Begin
    {
     <# This is sometimes known as “New State”, “Token Privileges”
        or “Tok Priv 1 Luid”  #>

        $TokenPrivilege = Add-TypeEx -InputObject 'TokenPrivilege' -OutputAssembly

     <# You cannot use a non-default type without referring to its assembly first.
        But you cannot refer to an assembly if it only exists in memory. Hence,
        we need to load the DLL file from the disk  #>

        $SecurityBaseApi = Add-TypeEx -InputObject 'SecurityBaseApi' -ReferencedAssembly $TokenPrivilege.Assembly.Location
    }

    Process
    {
       #region    Create instance of “Token Privilege” and populate it

            $NewState = $TokenPrivilege::new()

            $NewState.Count = 1
            $NewState.Luid  = $InputObject
            $NewState.Attr  = $Attribute

       #endregion Create instance of “Token Privilege” and populate it

       #region    Run “Adjust Token Privilege” function

            $Argument = @(
              # Token Handle
                [System.IntPtr]                             $Token
              # Disable All Privileges
                [System.Boolean]                            $False
              # New State
              # [System.Management.Automation.psReference]  $NewState
                [ref]                                       $NewState
              # Buffer Length
                [System.Int32]                              $Null
              # Previous State
                [System.IntPtr]::Zero
              # Return Length
                [System.IntPtr]::Zero
            )

            if
            (        
                $SecurityBaseApi::AdjustTokenPrivileges.Invoke( $Argument )
            )
            {
                $Message = 'Success'
                Write-Message -Channel Debug -Message $Message
            }
            else        
            {
                throw [System.ComponentModel.Win32Exception]::new()
            }        

       #endregion Run “Adjust Token Privilege” function
    }

    End
    {}
}