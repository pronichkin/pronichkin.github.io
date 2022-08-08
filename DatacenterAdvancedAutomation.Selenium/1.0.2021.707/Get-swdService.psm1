Set-StrictMode -Version 'Latest'

Function
Get-swdService
{
 <#
       .Synopsis
        Obtain Selenium service binary (driver) that matches the browser
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [OutputType(
        [System.IO.FileInfo]
    )]

    Param
    (    
        [System.Management.Automation.AliasAttribute(
            'Browser'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.FileInfo]
        $InputObject
    )

    End
    {
        Switch
        (
            $InputObject.FullName
        )
        {
            {
                $psItem.StartsWith( $env:LocalAppData )
            }
            {
             <# Using the Browser which is installed per-user. Because the binary
                is located in user profile, it is writeable and we can put the
                driver there  #>

                $Path = $InputObject.Directory
            }
        
            {
                $psItem.StartsWith( ${env:ProgramFiles(x86)} )
            }
            {
             <# Using the Browser which is installed per-system. Normal users do
                not have permissions to write there. Hence putting the driver into
                user temporary directory  #>

                $Path = Get-Item -Path $env:Temp
            }

            Default
            {
                $Message = 'Unexpected browser path'
                Write-Message -Channel Error -Message $Message
            }
        }

        $Service = Get-ChildItem -Path $Path.FullName -Filter 'msedgedriver.exe'

        [System.Version]$Version = $InputObject.VersionInfo.FileVersion

        If
        (
            $Service -and
            [System.Version]$Service.VersionInfo.FileVersion -eq $Version
        )
        {
            $Message = "Web Driver service version $Version found at `“$Path`”"
            Write-Message -Channel Verbose -Message $Message
        }
        Else
        {
            $Message = "Web Driver service not found at `“$Path`” or version not $Version. Downloading"
            Write-Message -Channel Verbose -Message $Message

            $PackageName = "edgedriver_win64 — $Version.zip"

            $PathParam = @{
            
                Path      = $env:Temp
                ChildPath = $PackageName
            }
            $PackagePath = Join-Path @PathParam
            
            [System.Uri]$ServicePackageUri =
                "https://msedgedriver.azureedge.net/$Version/edgedriver_win64.zip"

            $RequestParam = @{
            
                Uri             = $ServicePackageUri
                OutFile         = $PackagePath
                UseBasicParsing = $True
                PassThru        = $True
                Verbose         = $False
            }
            $ServicePackage = Invoke-WebRequest @RequestParam

            $ArchiveParam = @{
            
                Path            = $PackagePath
                DestinationPath = $Path
                Force           = $True
                Verbose         = $False
            }
            Expand-Archive @ArchiveParam

            $Service = Get-ChildItem -Path $Path -Filter 'msedgedriver.exe'
        }

        Return $Service
    }
}