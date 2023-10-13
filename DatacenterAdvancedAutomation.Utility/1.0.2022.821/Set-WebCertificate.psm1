Set-StrictMode -Version 'Latest'

Function
Set-WebCertificate
{
    [cmdletBinding(
      # DefaultParameterSetName = ""
    )]

    Param(
        
            [parameter(
                ParameterSetName = "CertificateManagement",
                Mandatory        = $True
            )]
            [parameter(
                ParameterSetName = "CertificateSite",
                Mandatory        = $True
            )]
            [System.Security.Cryptography.X509Certificates.X509Certificate2]
            $Certificate
        ,
            [parameter(
                ParameterSetName = "PfxManagement",
                Mandatory        = $True
            )]
            [parameter(
                ParameterSetName = "PfxSite",
                Mandatory        = $True
            )]
            [System.IO.FileInfo]
            $PFX
        ,
            [parameter(
                ParameterSetName = "CertificateSite",
                Mandatory        = $True
            )]
            [parameter(
                ParameterSetName = "PfxSite",
                Mandatory        = $True
            )]
            [Microsoft.IIs.PowerShell.Framework.ConfigurationElement]
            $WebSite
        ,
            [parameter(
                ParameterSetName = "CertificateSite",
                Mandatory        = $True
            )]
            [parameter(
                ParameterSetName = "PfxSite",
                Mandatory        = $True
            )]
            [System.String]
            $Address
        ,
            [parameter(
                ParameterSetName = "CertificateSite",
                Mandatory        = $False
            )]
            [parameter(
                ParameterSetName = "PfxSite",
                Mandatory        = $False
            )]
            [System.Net.IPAddress]
            $IpAddress
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateSet( "HTTP", "HTTPS" )]
            [System.String]
            $Protocol = "HTTPS"
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateSet( "80", "443" )]
            [System.Int32]
            $Port = 443
    )

    Process
    {
   
      # Write-Verbose -Message "Entering Set-WebCertificate in $($psCmdlet.ParameterSetName) Mode"

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            {
                (
                    $psItem -eq "PfxManagement"
                ) -or (
                    $psItem -eq "PfxSite"
                )
            }
            {
                $Message = "Please enger password for the PFX file"

                $Password = ( Get-Credential -Message $Message ).Password
            
                $ImportPfxCertificateParam = @{

                    Password = $Password
                    CertStoreLocation = "Cert:\localMachine\My"
                    FilePath = $PFX.ToString()
                }
                $Certificate = Import-PfxCertificate @ImportPfxCertificateParam
            }
        }

        $CertificateThumbprint = $Certificate.Thumbprint

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {

          # Set Certificate binding for Web Management Service

            {
                (
                    $psItem -eq "PfxManagement"
                ) -or (
                    $psItem -eq "CertificateManagement"
                )
            }
            {
	    
              # Split certificate's thumbprint to Hex octets

	            $Tokens = $CertificateThumbprint -split "([a-fA-F0-9]{2})" | Where-Object -FilterScript { $psItem }
	    
              # Convert each octet to a byte and write them to a byte array

	            [Byte[]]$Bytes = $Tokens | ForEach-Object -Process { [Convert]::ToByte($psItem, 16) }

	            Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WebManagement\Server -Name SslCertificateHash -Value $Bytes
        
              # Addjust SSL Certificate binding for HTTP driver.
              # For the Web Management Service, this does not happen automatically.

                $SetHttpSslServerCertificateBindingParam = @{

                    IpAddressString       = "0.0.0.0"
                    Port                  = 8172
                    Application           = "WebManagement"
                    CertificateThumbprint = $CertificateThumbprint
                }
                Set-HttpSslServerCertificateBinding @SetHttpSslServerCertificateBindingParam
            }

          # Set Certificate binding for Web Site in IIS

            {
                (
                    $psItem -eq "PfxSite"
                ) -or (
                    $psItem -eq "CertificateSite"
                )
            }
            {
                If
                (
                    $IpAddress
                )
                {
                    $IpAddressString = $IpAddress.IpAddressToString
                }
                Else
                {
                    $IpAddressString = "*"
                }

                $WebSiteName = $WebSite.Name
            
                $WebBinding = Get-WebBinding -Name $WebSiteName -Protocol $Protocol
            
                If
                (
                    $WebBinding
                )
                {
                    $WebBinding | ForEach-Object -Process {
                        Remove-WebBinding -InputObject $psItem
                    }
                }

                $WebBindingParam = @{

                    Name       = $WebSiteName                    
                    Port       = $Port
                    HostHeader = $Address
                    IpAddress  = $IpAddressString
                    SslFlags   = 1
                    Protocol   = $Protocol
                }
                $WebBinding = New-WebBinding @WebBindingParam

                If
                (
                    $Protocol -eq "HTTPS"
                )
                {
                    $WebBinding = Get-WebBinding -Name $WebSiteName -Protocol "HTTPS"
                    $WebBinding.AddSslCertificate( $CertificateThumbprint, "My" )

                    $SetWebConfigurationParam = @{

                        Location = $WebSiteName
                        Filter   = "system.webserver/security/access"
                        Value    = "Ssl"
                    }
                    $WebConfiguration = Set-WebConfiguration @SetWebConfigurationParam
                }
                Else
                {
                    $SetWebConfigurationParam = @{

                        Location = $WebSiteName
                        Filter   = "system.webserver/security/access"
                      # Value    = "Ssl"
                    }
                    $WebConfiguration = Clear-WebConfiguration @SetWebConfigurationParam
                }

                Start-Website -Name $WebSiteName

              # No need to addjust SSL Certificate binding for HTTP driver.
              # For IIS Web Sites, this happens automatically.

            }
        }

      # Write-Verbose -Message "Exiting  Set-WebCertificate in $($psCmdlet.ParameterSetName) Mode"
    }
}