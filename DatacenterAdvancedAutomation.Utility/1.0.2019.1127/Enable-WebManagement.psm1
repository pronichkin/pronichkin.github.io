Function
Enable-WebManagement
{

   #region Data

        [cmdletBinding()]

        Param(
        
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $CertificateTemplateName
        ,
            [Parameter(
                Mandatory = $False
            )]
            [System.Management.Automation.SwitchParameter]
            $ForceNewCertificate
        )

   #endregion Data

   #region Code

      # Enable Feature: Web Server (IIS) \ Management Tools \ Management Service
        
        Install-WindowsFeatureEx -FeatureName "Web-Mgmt-Service"

      # Define Web Management Service settings

        If
        (
            ( Get-Service -Name "WMSvc" ).Status -eq "Running"
        )
        {
            $Service = Stop-Service -Name "WMSvc" -PassThru
        }

	    If
        (
           -Not
            (
               Test-Path -Path "HKLM:\SOFTWARE\Microsoft\WebManagement\Server"
            )
        )
        {
            $NewItemParam = @{

                Path = "HKLM:\SOFTWARE\Microsoft\WebManagement"
                Name = "Server"
            }
		    $Key = New-Item @NewItemParam
	    }

        $SetItemPropertyParam = @{

            Path  = "HKLM:\SOFTWARE\Microsoft\WebManagement\Server"
            Name  = "EnableRemoteManagement"
            Value = 1
        }
        Set-ItemProperty @SetItemPropertyParam

      # Obtain Certificate

      # We assume that if a Certificate Template Name was supplied in Parameters
      # this means that we're using a trusted Certification Authority to request
      # Certificates. Otherwise, request step will be skipped. Effectively, a
      # Self-Signed certificate will be used for Web Management Service.

        If
        (
            $CertificateTemplateName
        )
        {
            $FriendlyName = "Web Management Service"
            
          # Check whether we already have a relevant Certificate

            $Certificate = Get-ChildItem -Path "Cert:\LocalMachine\My" |
                Where-Object -FilterScript {

                    $psItem.FriendlyName -eq $FriendlyName
                }

            If
            (
                $ForceNewCertificate -Or -Not $Certificate
            )
            {
                $GetWebCertificateParam = @{

                    TemplateName  = $CertificateTemplateName
                    FriendlyName  = $FriendlyName
                }
                $Certificate = Get-WebCertificate @GetWebCertificateParam
            }
            Else
            {
                Write-Verbose -Message "Using existing certificate $( $Certificate.Thumbprint )"
            }

          # Some object types from “Web Administration” module
          # are used in “Set-WebCertificate” function.

            $Module = Import-ModuleEx -Name "WebAdministration"

            Set-WebCertificate -Certificate $Certificate
        }

      # Configure Service state

        $Service = Set-Service   -Name "WMSvc" -StartupType "Automatic" -PassThru
        $Service = Start-Service -Name "WMSvc" -PassThru

   #endregion Code

}