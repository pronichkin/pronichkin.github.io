Function
Set-MemoryDumpConfiguration
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.psSession[]]
        $Session
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ThumbPrint
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Byte[]]
        $PublicKey
    )

    Process
    {
        $CrashControl = 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl'

        Invoke-Command -Session $Session -scriptBlock {

            Set-ItemProperty -Path "$using:CrashControl" -Name 'CrashDumpEnabled'      -Type DWord  -Value 1  # Full memory dump (Same for Active). MAS sets “2” which is Kernel dump.
            Set-ItemProperty -Path "$using:CrashControl" -Name 'FilterPages'           -Type DWord  -Value 1  # Active memory dump
            Set-ItemProperty -Path "$using:CrashControl" -Name 'DumpEncryptionEnabled' -Type DWord  -Value 1
            Set-ItemProperty -Path "$using:CrashControl" -Name 'NmiCrashDump'          -Type DWord  -Value 1
            Set-ItemProperty -Path "$using:CrashControl" -Name 'DedicatedDumpFile'     -Type String -Value 'd:\DedicatedDumpFile.sys'
            Set-ItemProperty -Path "$using:CrashControl" -Name 'DumpFileSize'          -Type DWord  -Value 32768  # 0 is supposed to be “automatic” but apparently does not work.
            Set-ItemProperty -Path "$using:CrashControl" -Name 'IgnorePagefileSize'    -Type DWord  -Value 1
            Set-ItemProperty -Path "$using:CrashControl" -Name 'AlwaysKeepMemoryDump'  -Type DWord  -Value 1

            Set-ItemProperty -Path "$using:CrashControl\ForceDumpsDisabled" -Name 'GuardedHost' -Value 0 -Type DWord

            [System.Void]( New-Item -Path "$using:CrashControl\EncryptionCertificates\Certificate.1" -Force )

            [System.Void]( New-ItemProperty -Path "$using:CrashControl\EncryptionCertificates\Certificate.1" -Name 'Thumbprint' -PropertyType 'String' -Value $using:ThumbPrint )
            [System.Void]( New-ItemProperty -Path "$using:CrashControl\EncryptionCertificates\Certificate.1" -Name 'PublicKey'  -PropertyType 'Binary' -Value $using:PublicKey  )        

            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1
        }
    }
}