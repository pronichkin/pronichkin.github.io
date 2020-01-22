Using Module '.\PrivilegeAttribute.psm1'

Set-StrictMode -Version 'Latest'

Function
Set-TokenPrivilege
{
    [CmdletBinding()]

    [OutputType([System.IntPtr])]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [System.IntPtr]
        $Token
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.Int64]
        $Privilege
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateSet(
            'Enable',
            'Disable'
        )]
        [System.String]
        $Action = 'Enable'
    )

    Begin
    {
      # https://docs.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-adjusttokenprivileges

        $MemberDefinition = @'

            [DllImport(
                "advapi32.dll",
                CharSet       = CharSet.Unicode,
                ExactSpelling = true,
                SetLastError  = true
            )]
            public static extern bool AdjustTokenPrivileges(
                IntPtr TokenHandle,
                bool   DisableAllPrivileges,
             // ref TOKEN_PRIVILEGES NewState,
                ref Object[] NewState,
             // UInt32 BufferLengthInBytes,
                int    BufferLength,                
             // ref TOKEN_PRIVILEGES PreviousState,
                IntPtr PreviousState,   
             // out UInt32 ReturnLengthInBytes);
                IntPtr ReturnLength
            );

         // [StructLayout(LayoutKind.Sequential, Pack = 1)]
         // internal struct TOKEN_PRIVILEGES
         // {
         //     public int  Count;
         //     public long Luid;
         //     public int  Attr;
         // }
'@

        $TypeParam = @{

            MemberDefinition = $MemberDefinition
            Name             = 'AdjustTokenPrivilegesClass'
            PassThru         = $True
            Debug            = $False
        }
        $AdjustTokenPrivilegesClass = Add-Type @TypeParam
    }

    Process
    {
        Switch
        (
            $Action
        )
        {
            'Enable'
            {
                $Attribute = [PrivilegeAttribute]::SE_PRIVILEGE_ENABLED
            }

            'Disable'
            {
                $Attribute = [PrivilegeAttribute]::SE_PRIVILEGE_ENABLED
            }
        }

        $NewState = @(

            [System.Int32] 1
            [System.Int64] $Privilege
            [System.Int32] $Attribute
        )
        
        $Argument = @(

          # [System.IntPtr]   $Token     # TokenHandle
            [System.IntPtr]   ( Get-ProcessToken -DesiredAccess Query, AdjustPrivileges )
            [System.Boolean]  $False     # DisableAllPrivileges
            [ref]             $NewState  # NewState
            [System.Int32]    $Null      # BufferLength
            [System.IntPtr]::Zero        # PreviousState
            [System.IntPtr]::Zero        # ReturnLength
        )       
    }

    End
    {
        If
        (        
            $AdjustTokenPrivilegesClass::AdjustTokenPrivileges.Invoke( $Argument )
        )
        {
            $Message = 'Success'
            Write-Debug -Message $Message
        }
        Else        
        {
            Throw [System.ComponentModel.Win32Exception]::new()
        }     
    }
}