        Class
        TokPriv1Luid
        {
            [int]$Count
            [long]$Luid
            [int]$Attr
        }

        $md1 = @'

            [StructLayout(LayoutKind.Sequential, Pack = 1)]
            public struct TokPriv1Luid
            {
                public int  Count;
                public long Luid;
                public int  Attr;
            }
'@

        $TypeParam = @{

            MemberDefinition = $md1
            Name             = 'TokPriv1LuidClass'
            PassThru         = $True
            Debug            = $False
        }
        $TokPriv1LuidClass = Add-Type @TypeParam


      # $NewState = [TokPriv1Luid]::new()
        $NewState = @(

            [System.Int32] 1
            [System.Int64] 20  # sedebugprivilege
            [System.Int32] 2   # SE_PRIVILEGE_ENABLED
        )
        
        $NewState = @{

            'Count' = [System.Int32] 1
            'Luid'  = [System.Int64] 20  # sedebugprivilege
            'Attr'  = [System.Int32] 2   # SE_PRIVILEGE_ENABLED
        }

      # $NewState = [TOKEN_PRIVILEGES]::new()




