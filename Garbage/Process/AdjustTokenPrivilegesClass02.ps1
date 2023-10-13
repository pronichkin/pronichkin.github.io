Import-Module -Name 'DatacenterAdvancedAutomation.Process'

$VerbosePreference     = [System.Management.Automation.ActionPreference]::Continue
$DebugPreference       = [System.Management.Automation.ActionPreference]::Continue
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version  'Latest'


#

$TypeDefinition = @'

         // [StructLayout(LayoutKind.Sequential, Pack = 1)]
         // public   class  TokPriv1Luid
            public   struct sss
         // internal struct TokPriv1Luid
            {
                public int  ccc;
                public long lll;
                public int  aaa;
            }
'@

        $TypeParam = @{

          # MemberDefinition = $MemberDefinition2
            TypeDefinition   = $TypeDefinition 
          # Name             = 'AdjustTokenPrivilegesClasssss'
          # Namespace        = 'dcaa'
            PassThru         = $True
            Debug            = $False
        }
        $AdjustTokenPrivilegesClasssss = Add-Type @TypeParam

        $MemberDefinition1 = @'

            [DllImport(
                "advapi32.dll",
             // CharSet       = CharSet.Unicode,
                ExactSpelling = true,
                SetLastError  = true
            )]
            public static extern bool AdjustTokenPrivileges(
                IntPtr TokenHandle,
                bool   DisableAllPrivileges,

             // ref TOKEN_PRIVILEGES   NewState,    // Custom
             // ref Object[]           NewState,    // The parameter is incorrect
             // ref sss                NewState,    // TypeDefinition --> The type or namespace name 'sss' could not be found
             // ref NewState           NewState,    // Class          --> The type or namespace name 'sss' could not be found
             // ref System.ValueType   NewState,
             // ref System.Management.Automation.PSObject NewState,
                ref Object             NewState,    // No error but does not change
             // ref dcaa.AdjustTokenPrivilegesClasssss+sss NewState,
             // ref ssss               NewState,

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
            public   struct ssss
         // internal struct TokPriv1Luid
            {
                public int  ccc;
                public long lll;
                public int  aaa;
            }
'@

        $TypeParam = @{

            MemberDefinition = $MemberDefinition1
            Name             = 'AdjustTokenPrivilegesClass'
            PassThru         = $True
            Debug            = $False
        }
        $AdjustTokenPrivilegesClass = Add-Type @TypeParam



        $NewState = $AdjustTokenPrivilegesClass[1]::new()

        $NewState = $AdjustTokenPrivilegesClasssss[1]::new()



       #region Type

        $NewState = [ssss]::new()
        $NewState.ccc  = 1
        $NewState.lll  = 5  # SeIncreaseQuotaPrivilege
        $NewState.aaa  = 2

       #endregion Type

       #region Class

        Class
        NewState
        {
            [int]$1
            [int]$2
            [int]$3
        }

        $NewState = [NewState]::new()

        $NewState.1 = 1
        $NewState.2 = 5
        $NewState.3 = 2

       #endregion Class

        $NewState = New-Object -TypeName 'psObject' -Property @{ 1 = 1; 2 = 5; 3 = 2 }
        
        $NewState = @( 1, 5, 2 )

        $NewState = [System.Collections.Generic.List[System.Object]]::new()
        $NewState.Add( 1 )

        $NewState1 = [System.Collections.Generic.List[System.Int32]]::new()
        $NewState1.Add( 5 )
        $NewState1.Add( 2 )

        $NewState.Add( $NewState1 )



        $NewState.Add( 5 )
        $NewState.Add( 2 )


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

.\whoami.exe /priv | .\findstr.exe /i SeIncreaseQuotaPrivilege

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

.\whoami.exe /priv | .\findstr.exe /i SeIncreaseQuotaPrivilege
