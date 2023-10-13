Set-StrictMode -Version 'Latest'

 <#
   .Synopsis
    Obtain process token

   .Description
    Obtain process token. This is basically a wrapper for Win32 “Open Process 
    Token” function found in Advapi32.dll

   .Example
    Get-ProcessToken

   .Link
    https://docs.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocesstoken
  #>

Function
Get-ProcessToken
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.IntPtr]
    )]

    Param(

        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.AliasAttribute(
            'Process'
        )]
        [System.Diagnostics.Process]
     <# The process on which to obtain the token
        Default is the current process  #>
        $InputObject = ( Get-Process -Id $pid )
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $False
        )]
        [System.Security.Principal.TokenAccessLevels]
     <# Desired Access Level(s). You can specify multiple values at once, e.g.
       “Query, AdjustPrivileges”. Default is “Maximum allowed”  #>
        $Access = [System.Security.Principal.TokenAccessLevels]::MaximumAllowed
    )

    Begin
    {
        $ProcessThreadsApi = Add-TypeEx -InputObject 'ProcessThreadsApi'
    }

    Process
    {
        $Message = "Obtaining token for process `“$($InputObject.Name)`” with desired access `“$Access`”"
        Write-Message -Channel Debug -Message $Message

        $TokenHandle = [System.IntPtr]::Zero

        $Argument = @(

            [System.IntPtr] $InputObject.Handle
            [System.Int32]  $Access
            [ref]           $TokenHandle
        )

        if
        (        
            $ProcessThreadsApi::OpenProcessToken.Invoke( $Argument )
        )
        {
            return $TokenHandle
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