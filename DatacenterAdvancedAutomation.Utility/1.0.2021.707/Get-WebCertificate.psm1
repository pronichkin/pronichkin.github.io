#####################################################################
# Get-WebCertificate.ps1
# Version 2.0
#
# Requests, installs and configures certificate for remote Web Administration
#
# Vadims Podans (c) 2013
# http://en-us.sysadmins.lv/
#
# Artem Pronichkin, 2014
# Artem.Pronichkin@Microsoft.com
#####################################################################
#requires -Version 2.0

Function
Get-WebCertificate
{
<#
.Synopsis
	Requests, installs and configures certificate for remote Web Administration.
.Description
	Requests, installs and configures certificate for remote Web Administration.
	
	The command performs the following tasks:
	1) Creates certificate request based on a specified certificate request and submits
		request to a CA server
	2) If certificate issued immediately, the command installs issued certificate.
		If certificate is pending for approval, the command attempts to issue pending
		request and install issued certificate.
	3) Registers issued certificate to use for Remote Web Administration.
	
	Permissions: the caller must have the following permissions:
	1) Local administrator permissions
	2) CA Manager permissions on CA server.
.Parameter TemplateName
	Specifies the target certificate template common name.
.Parameter ConfigString
	Specifies CA server's configuration string in the format: CAHostName\CAName
	If parameter is null (or not specified), the function behavior is the following:
	1) Enumerate all Enterprise CAs in the forest
	2) Determine CAs that support certificate template specified in the TemplateName parameter
	3) Create and submit certificate request to a supported CA
	4) Install issued certificate
	
	if parameter is specified and is not null, only steps 3 and 4 are performed.
.Parameter FriendlyName
	Specifies certificate friendly name. This parameter is optional.
#>
[cmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
    	[string]$FriendlyName,

		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
        [string]$SubjectName,		
        [string]$TemplateName,        
        [string]$ConfigString,
        [String[]]$SubjectAlternativeName
      # ,
      # [switch]$WebManagement
	)

    If
    (
        [System.String]::IsNullOrWhiteSpace( $SubjectName )
    )
    {
	    $SubjectName = "CN=$([Net.Dns]::GetHostByName((hostname)).HostName)"
    }

    If
    (
        [System.String]::IsNullOrWhiteSpace( $TemplateName )
    )
    {
        Write-Verbose -Message "Certificate Template Name was not provided. Creating a Self-Signed Certificate"

        $NewSelfSignedCertificateExParam = @{

            Subject                = $SubjectName
            FriendlyName           = $FriendlyName
            SubjectAlternativeName = $SubjectAlternativeName
            KeyUsage               = @( "KeyEncipherment, DigitalSignature" )
            EnhancedKeyUsage       = @( "Server Authentication", "Client authentication" )
            StoreLocation          = "LocalMachine"
            KeyLength              = 4096
        }        
        $Cert = New-SelfSignedCertificateEx @NewSelfSignedCertificateExParam
    }
    Else
    {
        Write-Verbose -Message "Requesting Certificate from Certification Authority (CA)"

        #region helper functions
	        function __resubmit($reqId,$config) {
		        Write-Host id: $reqId
		        Write-Host config: $config
		        $CertAdmin = New-Object -ComObject CertificateAuthority.Admin
		        $disp = $CertAdmin.Resubmitrequest($config,$reqId)
		        if ($disp -ne 3) {throw "Certificate was not issued. Disposition code: $disp"}
	        }
	        function __installResponse($reqId,$config,$Base64) {		
		        $Response = New-Object -ComObject X509Enrollment.CX509Enrollment
                $Response.Initialize(0x2)
                $Response.InstallResponse(0x4,$Base64,0x1,"")
	        }
        #endregion

        #region initialize interfaces
	        $CertRequest = New-Object -ComObject CertificateAuthority.Request
	        $Subject = New-Object -ComObject X509Enrollment.CX500DistinguishedName
	        $PKCS10 = New-Object -ComObject X509Enrollment.CX509CertificateRequestPkcs10
	        $Request = New-Object -ComObject X509Enrollment.CX509Enrollment
        #endregion

        #region Some constants
	        $UserContext = 1
	        $MachineContext = 2
	        $Base64requestHeader = 3

            # SANs
            New-Variable -Name OtherName -Value 0x1 -Option Constant
            New-Variable -Name RFC822Name -Value 0x2 -Option Constant
            New-Variable -Name DNSName -Value 0x3 -Option Constant
            New-Variable -Name DirectoryName -Value 0x5 -Option Constant
            New-Variable -Name URL -Value 0x7 -Option Constant
            New-Variable -Name IPAddress -Value 0x8 -Option Constant
            New-Variable -Name RegisteredID -Value 0x9 -Option Constant
            New-Variable -Name Guid -Value 0xa -Option Constant
            New-Variable -Name UPN -Value 0xb -Option Constant

        #endregion
	        # Grab template settings and prepare certificate request.
	        $PKCS10.InitializeFromTemplateName($MachineContext,$TemplateName)

            $Subject.Encode("$SubjectName",0)
            $PKCS10.Subject = $Subject

                if ($SubjectAlternativeName) {
                $SAN = New-Object -ComObject X509Enrollment.CX509ExtensionAlternativeNames
                $Names = New-Object -ComObject X509Enrollment.CAlternativeNames
                foreach ($altname in $SubjectAlternativeName) {
                    $Name = New-Object -ComObject X509Enrollment.CAlternativeName
                    if ($altname.Contains("@")) {
                        $Name.InitializeFromString($RFC822Name,$altname)
                    } else {
                        try {
                            $Bytes = [Net.IPAddress]::Parse($altname).GetAddressBytes()
                            $Name.InitializeFromRawData($IPAddress,$Base64,[Convert]::ToBase64String($Bytes))
                        } catch {
                            try {
                                $Bytes = [Guid]::Parse($altname).ToByteArray()
                                $Name.InitializeFromRawData($Guid,$Base64,[Convert]::ToBase64String($Bytes))
                            } catch {
                                try {
                                    $Bytes = ([Security.Cryptography.X509Certificates.X500DistinguishedName]$altname).RawData
                                    $Name.InitializeFromRawData($DirectoryName,$Base64,[Convert]::ToBase64String($Bytes))
                                } catch {$Name.InitializeFromString($DNSName,$altname)}
                            }
                        }
                    }
                    $Names.Add($Name)
                }
                $SAN.InitializeEncode($Names)
                $PKCS10.X509Extensions.Add( $SAN )
            }
    
            $Request.InitializeFromRequest($PKCS10)
	        $Request.CertificateFriendlyName = $FriendlyName
	        # enroll from default CA
	        if ([string]::IsNullOrEmpty($ConfigString)) {
		        # enroll from default CA
		        $Request.Enroll()
		        # request is pending for approval
		        if ($Request.Status.Status -eq 2) {
			        # if request is placed in pending state, attempt to resubmit it
			        __resubmit $Request.RequestId $Request.CAConfigString
			        # retrieve issued certificate
			        [void]$CertRequest.RetrievePending($Request.RequestId,$Request.CAConfigString)
			        # save cert to a X509Certificate2 object for subsequent calls
			        $Cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList `
				        @(,[Convert]::FromBase64String($CertRequest.GetCertificate(1)))
			        # install issued certificate to local machine store
			        __installResponse $Request.RequestId $Request.CAConfigString $CertRequest.GetCertificate(1)
		        # request was issued immediately
		        } elseif ($Request.Status.Status -eq 1) {
			        # save cert to a X509Certificate2 object for subsequent calls
			        $Cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList `
				        @(,[Convert]::FromBase64String($Request.Certificate(1)))
		        }
	        } else {
		        $CertRequest = New-Object -ComObject CertificateAuthority.Request
		        $Base64 = $Request.CreateRequest($Base64requestHeader)
		        $Status = $CertRequest.Submit(0xff,$Base64,$null,$ConfigString)
		        switch ($Status) {
			        # request was issued immediately
			        3 {
				        # save cert to a X509Certificate2 object for subsequent calls
				        $Cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList `
					        @(,[Convert]::FromBase64String($CertRequest.GetCertificate(1)))
				        # install issued certificate to local machine store
				        __installResponse $Request.RequestId $Request.CAConfigString $CertRequest.GetCertificate(1)
			        }
			        # request is pending for approval
			        5 {
				        # if request is placed in pending state, attempt to resubmit it
				        __resubmit $CertRequest.GetRequestId() $ConfigString
				        # retrieve issued certificate
				        [void]$CertRequest.RetrievePending($CertRequest.GetRequestId(),$ConfigString)
				        # save cert to a X509Certificate2 object for subsequent calls
				        $Cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList `
					        @(,[Convert]::FromBase64String($CertRequest.GetCertificate(1)))
				        # install issued certificate to local machine store
				        __installResponse $CertRequest.GetRequestId() $ConfigString $CertRequest.GetCertificate(1)
			        }
		        }
	        }
        }

    $Cert
}