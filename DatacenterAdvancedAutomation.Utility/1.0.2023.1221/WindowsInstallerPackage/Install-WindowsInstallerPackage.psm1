Set-StrictMode -Version 'Latest'

Function
Install-WindowsInstallerPackage
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [System.IO.FileInfo]
        $Package
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Boolean]
        $Admin
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.String]
        $Path
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.Runspaces.psSession[]]
        $Session
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Collections.Hashtable]
        $Property
    )

    Process
    {   
        $JoinPathParam = @{

            Path      = $env:SystemRoot
            ChildPath = 'System32\msiExec.exe'
        }
        $WindowsInstallerPath = Join-Path @JoinPathParam
    
        $PackagePath    = $Package.FullName
        $PackageName    = $Package.BaseName
        $PackageType    = ( $PackagePath ).Split( '.' )[-1]

        $InstallPackageParam  =   [String]::Empty
        $InstallPackageParam += ' /Passive'
        $InstallPackageParam += ' /NoRestart'

        Switch 
        (
            $PackageType
        )
        {
            'msi'
            {
                If
                (
                    $Admin
                )
                {
                    $InstallPackageParam += ' /a       "' + $PackagePath + '"'
                }                
                Else
                {                
                    $InstallPackageParam += ' /Package "' + $PackagePath + '"'
                }
            }
            'msp'
            {
                $InstallPackageParam     += ' /Update  "' + $PackagePath + '"'
            }
        }

        If
        (
            $Path
        )
        {
            $InstallPackageParam += " TargetDir=""$Path"""
        }

        If
        (
            $Property
        )
        {
            $Property.GetEnumerator() | ForEach-Object -Process {

                $InstallPackageParam += " $( $psItem.Key )=""$( $psItem.Value )"""
            }
        }

        If
        (
            $Session
        )
        {
            $Session | ForEach-Object -Process {
            
                $ComputerName = $psItem.ComputerName
                $ComputerName = ( Get-Culture ).TextInfo.ToTitleCase(
                    $( Resolve-dnsNameEx -Name $ComputerName ).toLower()
                )

                Write-Verbose -Message $ComputerName

                $Install = Invoke-Command -Session $psItem -scriptBlock {

                    $DateTime       =  Get-Date -Format 'FileDateTimeUniversal'
                    $PackageLogName = "$using:ComputerName—$DateTime—$using:PackageName.wil"
                    $PackageLogPath =  Join-Path -Path $env:Temp -ChildPath $PackageLogName

                    $InstallPackageParamLocal = $using:InstallPackageParam + " /L*vx ""$PackageLogPath"""

                    $StartProcessParam = @{

                        FilePath     = $using:WindowsInstallerPath
                        ArgumentList = $InstallPackageParamLocal
                        Wait         = $True
                        PassThru     = $True
                        NoNewWindow  = $True
                    }
                    $Process = Start-Process @StartProcessParam
                    
                    $Process.ExitCode
                    $PackageLogPath
                }

                If
                (
                    $Install[0] -eq 3010
                )
                {
                    $Message = 'Installation required system restart'
                    Write-Warning -Message $Message
                    Restart-Computer -Confirm -ComputerName $psItem.ComputerName -Wait
                }
                ElseIf
                (
                    $Install[0] -ne 0
                )
                {
                    $Message  = "Installation Failed. Please review log at `“$($Install)[1]`” on the remote machine"
                    Write-Warning -Message $Message                    
                }

            }
        }
        Else
        {
            $ComputerName = $env:ComputerName
            $ComputerName = ( Get-Culture ).TextInfo.ToTitleCase(
                $( Resolve-dnsNameEx -Name $ComputerName ).toLower()
            )

            $DateTime       =  Get-Date -Format 'FileDateTimeUniversal'
            $PackageLogName = "$ComputerName—$DateTime—$PackageName.wil"
            $PackageLogPath =  Join-Path -Path $env:Temp -ChildPath $PackageLogName

            $InstallPackageParam += " /L*vx ""$PackageLogPath"""

            $StartProcessParam = @{

                FilePath     = $WindowsInstallerPath
                ArgumentList = $InstallPackageParam
                Wait         = $True
                PassThru     = $True
                NoNewWindow  = $True
            }
            $Install = Start-Process @StartProcessParam

            If
            (
                $Install.ExitCode -eq 3010
            )
            {
                $Message = 'Installation required system restart'
                Write-Warning -Message $Message
                Restart-Computer -Confirm
                Return $Install.ExitCode
            }
            ElseIf
            (
                $Install.ExitCode -ne 0
            )
            {
                $Message  = "Installation Failed. Please review log at `“$PackageLogPath`”"
                Write-Warning -Message $Message
                Start-Process -FilePath 'notepad.exe' -ArgumentList """$PackageLogPath"""
                Return $Install.ExitCode
            }
        }
    }
}