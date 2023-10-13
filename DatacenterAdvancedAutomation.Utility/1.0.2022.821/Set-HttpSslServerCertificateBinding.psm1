Set-StrictMode -Version 'Latest'

Function
Set-HttpSslServerCertificateBinding
{
    [cmdletBinding()]

    Param(
        
            [Parameter(
                ParameterSetName = "IpPort",
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $IpAddressString
        ,
            [Parameter(
                ParameterSetName = "HostnamePort",
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $HostName
        ,
            [Parameter(
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $Port
        ,
            [Parameter(
                Mandatory        = $True
            )]
            [ValidateSet(
                "WebManagement",
                "WebSite"
            )]
            [System.String]
            $Application
        ,
            [Parameter(
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $CertificateThumbprint
    )

    Process
    {
        $NetShell = Join-Path -Path $env:WinDir -ChildPath "System32\NetSh.exe"

        Switch
        (
            $Application
        )
        {
            "WebManagement"
            {
                $AppId = "{d7d72267-fcf9-4424-9eec-7e1d8dcec9a9}"
            }
            
            "WebSite"
            {
                $AppId = "{4dc3e181-e14b-4a21-b022-59fc669b0914}"
            }
        }

        $Argument = @(

            "http"
            "show"
            "sslcert"
        )

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            "IpPort"
            {
                $IpPort       = "$($IpAddressString):$Port"
                $Argument    += "IpPort=$IpPort"
            }

            "HostnamePort"
            {
                $HostnamePort = "$($HostName):$Port"
                $Argument    += "HostnamePort=$HostnamePort"
            }
        }

        $StartProcessParam = @{

            FilePath     = $NetShell
            ArgumentList = $Argument
            NoNewWindow  = $True
            Wait         = $True
            PassThru     = $True
        }
        $Process = Start-Process @StartProcessParam

        If
        (
            $Process.ExitCode -eq 0
        )
        {

          # This means that Netsh returned something, i.e. there's an existing binding

            $Argument[1] = "Delete"

            $StartProcessParam = @{

                FilePath     = $NetShell
                ArgumentList = $Argument
                NoNewWindow  = $True
                Wait         = $True
                PassThru     = $True
            }
            $Process = Start-Process @StartProcessParam
        }

        $Argument[1] = "Add"

        $Argument += "CertHash=$CertificateThumbprint"
        $Argument += "AppId=$AppId"
        $Argument += "CertStore=My"

        $StartProcessParam = @{

            FilePath     = $NetShell
            ArgumentList = $Argument
            NoNewWindow  = $True
            Wait         = $True
            PassThru     = $True
        }
        $Process = Start-Process @StartProcessParam

      # Return $Process.ExitCode
    }
}