 <# 
    Import-Module and the #requires statement only import the module functions,
    aliases, and variables, as defined by the module. Classes are not imported.
    The using module command imports the module and also loads the class
    definitions

    https://docs.microsoft.com/powershell/module/microsoft.powershell.core/about/about_using
  #>

using module '.\Privilege.psm1'

Set-StrictMode -Version 'Latest'

<#
   .Synopsis
    Obtain locally unique identifier (LUID) value for a Privilege constant

   .Description
    Obtain locally unique identifier (LUID) value for a Privilege constant. This
    is basically a wrapper for Win32 “Lookup Privilege Value” function found in
    Advapi32.dll

   .Example
    Get-Privilege -Name 'SeSecurityPrivilege' | Set-TokenPrivilege

   .Link
    https://docs.microsoft.com/windows/win32/api/winbase/nf-winbase-lookupprivilegevaluew
#>

Function
Get-Privilege
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Int64]
    )]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.AliasAttribute(
            'Name'
        )]
        [Privilege]
     <# Privilege display name  #>
        $InputObject
    )

    begin
    {
        $WinBase = Add-TypeEx -InputObject 'WinBase'
    }

    process
    {
        $Message = "Looking up privilege `“$InputObject`”"
        Write-Message -Channel Debug -Message $Message

        [System.Int64]$Luid = 0

        $Argument = @(
          # System Name
            [System.String]::Empty
          # Name
            [System.String]                             $InputObject
          # Luid
          # [System.Management.Automation.psReference]  $Luid
            [ref]                                       $Luid
        )

        if
        (        
            $WinBase::LookupPrivilegeValueW.Invoke( $Argument )
        )
        {
            return $Luid
        }
        else        
        {
            throw [System.ComponentModel.Win32Exception]::new()
        }
    }

    end
    {
    }
}