Set-StrictMode -Version 'Latest'

Function
Get-ProcessToken
{
    [CmdletBinding()]

    [OutputType([System.IntPtr])]

    Param(

      # The process on which to obtain the token
      # Defaults to the current process
        [Parameter(
            Mandatory = $False
        )]
        [System.Diagnostics.Process]
        $Process = ( Get-Process -Id $pid )
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.Security.Principal.TokenAccessLevels]
        $DesiredAccess
    )

    Begin
    {
      # https://docs.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-openprocesstoken

        $MemberDefinition = @'

            [DllImport(
                "advapi32.dll",
                CharSet       = CharSet.Unicode,
                ExactSpelling = true,
                SetLastError  = true
            )]
            public static extern bool OpenProcessToken(
                IntPtr ProcessHandle,
                Int32  DesiredAccess,
                ref IntPtr TokenHandle
            );
'@

        $TypeParam = @{

            MemberDefinition = $MemberDefinition
            Name             = 'OpenProcessTokenClass'
            PassThru         = $True
            Debug            = $False
        }
        $OpenProcessTokenClass = Add-Type @TypeParam
    }

    Process
    {
        $Message = "Obtaining token for process `“$($Process.Name)`” with Desired Access `“$DesiredAccess`”"
        Write-Debug -Message $Message

        $TokenHandle = [System.IntPtr]::Zero

        $Argument = @(

            [System.IntPtr] $Process.Handle
            [System.Int32]  $DesiredAccess
            [ref]$TokenHandle
        )       
    }

    End
    {
        If
        (        
            $OpenProcessTokenClass::OpenProcessToken.Invoke( $Argument )
        )
        {
            Return $TokenHandle
        }
        Else        
        {
            Throw [System.ComponentModel.Win32Exception]::new()
        }     
    }
}