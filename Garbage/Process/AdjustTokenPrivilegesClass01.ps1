Import-Module -Name 'DatacenterAdvancedAutomation.Process'

$VerbosePreference     = [System.Management.Automation.ActionPreference]::Continue
$DebugPreference       = [System.Management.Automation.ActionPreference]::Continue
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version  'Latest'


# This works, where we have both struct and method in the same file

$name = 'SeIncreaseQuotaPrivilege'

        $MemberDefinition = @'

            [DllImport(
                "advapi32.dll",
             // CharSet       = CharSet.Unicode,
                ExactSpelling = true,
                SetLastError  = true
            )]
            public static extern bool AdjustTokenPrivileges(
                IntPtr TokenHandle,
                bool   DisableAllPrivileges,
             // ref TOKEN_PRIVILEGES NewState,
             // ref Object[] NewState,
                ref TokPriv1Luid NewState,
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

            [StructLayout(LayoutKind.Sequential, Pack = 1)]
         // public   class  TokPriv1Luid
            public   struct TokPriv1Luid
         // internal struct TokPriv1Luid
            {
                public int  Count;
                public long Luid;
                public int  Attr;
            }
'@

        $TypeParam = @{

            MemberDefinition = $MemberDefinition
            Name             = 'AdjustTokenPrivilegesClass'
            PassThru         = $True
            Debug            = $False
        }
        $AdjustTokenPrivilegesClass = Add-Type @TypeParam

        $NewState = $AdjustTokenPrivilegesClass[1]::new()

        $NewState.Count = 1
      # $NewState.Luid  = 5  # SeIncreaseQuotaPrivilege
        $NewState.Luid  = Get-Privilege -Name $name
        $NewState.Attr  = 2

        $Argument = @(

          # [System.IntPtr]   $Token     # TokenHandle
            [System.IntPtr]   ( Get-ProcessToken -DesiredAccess Query, AdjustPrivileges )
            [System.Boolean]  $False     # DisableAllPrivileges
          # [ref]             $NewState  # NewState
            [ref]             $NewState  # NewState
            [System.Int32]    $Null      # BufferLength
            [System.IntPtr]::Zero        # PreviousState
            [System.IntPtr]::Zero        # ReturnLength
        )

whoami.exe /priv | findstr.exe /i $name

        If
        (        
            $AdjustTokenPrivilegesClass[0]::AdjustTokenPrivileges.Invoke( $Argument )
        )
        {
            $Message = 'Success'
            Write-Debug -Message $Message
        }
        Else        
        {
            Throw [System.ComponentModel.Win32Exception]::new()
        }   

whoami.exe /priv | findstr.exe /i $name