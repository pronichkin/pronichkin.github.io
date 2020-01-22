Using Module '.\Privilege.psm1'

Set-StrictMode -Version 'Latest'

Function
Get-Privilege
{
    [CmdletBinding()]

    [OutputType([System.Int64])]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [Privilege]
        $Name
    )

    Begin
    {
      # https://docs.microsoft.com/windows/win32/api/winbase/nf-winbase-lookupprivilegevaluew

        $MemberDefinition = @'

            [DllImport(
                "advapi32.dll",
                CharSet       = CharSet.Unicode,
                ExactSpelling = true,
                SetLastError  = true
            )]
            public static extern bool LookupPrivilegeValueW(
                string lpSystemName,
                string lpName,
                ref long lpLuid
            );
'@

        $TypeParam = @{

            MemberDefinition = $MemberDefinition
            Name             = 'LookupPrivilegeValueClass'
            PassThru         = $True
            Debug            = $False
        }
        $LookupPrivilegeValueClass = Add-Type @TypeParam
    }

    Process
    {
        $Message = "Looking up privilege `“$Name`”"
        Write-Debug -Message $Message

        [System.Int64]$lpLuid = 0

        $Argument = @(

            [System.String]::Empty
            [System.String] $Name
            [ref]$lpLuid
        )
    }

    End
    {
        If
        (        
            $LookupPrivilegeValueClass::LookupPrivilegeValueW.Invoke( $Argument )
        )
        {
            Return $lpLuid
        }
        Else        
        {
            Throw [System.ComponentModel.Win32Exception]::new()
        }    
    }
}