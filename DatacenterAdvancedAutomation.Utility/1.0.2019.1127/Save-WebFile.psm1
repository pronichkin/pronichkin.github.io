#region Data

    $Uri = @(

      # "https://go.microsoft.com/fwlink/?linkid=829578"
      # "https://download.microsoft.com/download/2/4/3/24374C5F-95A3-41D5-B1DF-34D98FF610A3/inetmgr_amd64_en-US.msi"
      # "http://download.windowsupdate.com/d/msdownload/update/software/updt/2018/05/windows10.0-kb4100403-x64_229adccbfbaebe0bc98e463dd83bacd7e28e9e5b.msu"
      # "https://download.sysinternals.com/files/ProcessExplorer.zip"
    
      # Report Viewer 2015
      # "https://download.microsoft.com/download/A/1/2/A129F694-233C-4C7C-860F-F73139CF2E01/ENU/x86/ReportViewer.msi"

      # Report Viewer 2012
      # "https://download.microsoft.com/download/F/B/7/FB728406-A1EE-4AB5-9C56-74EB8BDDF2FF/ReportViewer.msi"

      # SQL Server 2017 CLR Types x64
      # "https://download.microsoft.com/download/C/1/9/C1917410-8976-4AE0-98BF-1104349EA1E6/x64/SQLSysClrTypes.msi"

      # SQL Server 2017 CLR Types x86
      # "https://download.microsoft.com/download/C/1/9/C1917410-8976-4AE0-98BF-1104349EA1E6/x86/SQLSysClrTypes.msi"

      # SQL Server 2012 Service Pack 4 CLR Types x64
      # "https://download.microsoft.com/download/F/3/C/F3C64941-22A0-47E9-BC9B-1A19B4CA3E88/ENU/x64/SQLSysClrTypes.msi"

      # SQL Server 2012 Service Pack 4 CLR Types x86
      # "https://download.microsoft.com/download/F/3/C/F3C64941-22A0-47E9-BC9B-1A19B4CA3E88/ENU/x86/SQLSysClrTypes.msi"

      # Windows 1803 RSAT
      # "https://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71FF9D98AB/WindowsTH-RSAT_WS_1803-x64.msu"

      # IIS manager for Remote administration
      # "https://download.microsoft.com/download/2/4/3/24374C5F-95A3-41D5-B1DF-34D98FF610A3/inetmgr_amd64_en-US.msi"

      # DISKSPD VMFleet
      # "https://codeload.github.com/Microsoft/diskspd/zip/master"

      # Windows 10 SDK 1809
      # "https://software-download.microsoft.com/download/pr/17763.1.180914-1434.rs5_release_WindowsSDK.iso"

      # PROCDUMP (for SMB case)
      # "https://download.sysinternals.com/files/Procdump.zip"

      # 'https://download.microsoft.com/download/C/4/F/C4F908C9-98ED-4E5F-88D5-7D6A5004AEBD/SQLServer2017-KB4484710-x64.exe'

        'https://download-evilangel.gammacdn.com/mp4/4/8/0/6/c76084/76084_05_4k.mp4?response-content-disposition=attachment%3Bfilename%3D%22BTS-SquirtingAdrianaGapingAnalSwallow_s05_AdrianaChechik_2160p.mp4%22&response-content-type=application%2Foctet-stream&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9kb3dubG9hZC1ldmlsYW5nZWwuZ2FtbWFjZG4uY29tL21wNC80LzgvMC82L2M3NjA4NC83NjA4NF8wNV80ay5tcDQ~cmVzcG9uc2UtY29udGVudC1kaXNwb3NpdGlvbj1hdHRhY2htZW50JTNCZmlsZW5hbWUlM0QlMjJCVFMtU3F1aXJ0aW5nQWRyaWFuYUdhcGluZ0FuYWxTd2FsbG93X3MwNV9BZHJpYW5hQ2hlY2hpa18yMTYwcC5tcDQlMjImcmVzcG9uc2UtY29udGVudC10eXBlPWFwcGxpY2F0aW9uJTJGb2N0ZXQtc3RyZWFtIiwiQ29uZGl0aW9uIjp7IkRhdGVMZXNzVGhhbiI6eyJBV1M6RXBvY2hUaW1lIjoxNTYzODczNzUzfX19XX0_&Signature=EerQuxaQKBPZ0pehTtr7TbfTBD~XervBxv54keH43xnrRqsPiZDkaTDjsxFOHi-D5rH2DM6f64--PHv30UEsEzcQ2oKQ3nKDfZ4jJNuZGx5LfitdU7b~MQtDtRCuYVo4uv7dyl5FYU8rE~QGQuQnb99ohE5e32S1S8E8B~v~Xal6z29Rv6DVMWW7QnN6wqk66T2RWT~JqPgDl2PpdsX~oYRCJ1z~r8MSI5NhuT8gzQpERTkan2yctWJbrCrspGSf3S6dZSnKIPEUGyB3AwJaFv5laZPt8N53SlJ7itqx2ILaLuCSxhQN2p0LEJGJZPX1ekCWuXe6bSmkUvWVBo2rwA__&Key-Pair-Id=APKAIRQBNEZPTJQK3JAQ'
    )

    $Destination = 'E:\Pornography\EA — dl'

  # $ProxyAddress  = "http://pslux.ec.europa.eu:8012"
  # $ProxyUserName = 'a002kmpc'
  # $ProxyPassword = '8+!!80zUp'

#endregion Data

#region Code

    If
    (
        [System.Net.ServicePointManager]::SecurityProtocol -notlike '*tls12*'
    )
    {
        [System.Net.ServicePointManager]::SecurityProtocol = 
        
             [System.Net.SecurityProtocolType]::Tls12 +
             [System.Net.ServicePointManager]::SecurityProtocol
    }

    $CrlPath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $AssemblyName = 'System.Net.Http.dll'
    $AssemblyPath = Join-Path -Path $CrlPath -ChildPath $AssemblyName
    Add-Type -Path $AssemblyPath
    
    $HttpClientHandler = [System.Net.Http.HttpClientHandler]::new()    

    If
    (
        Test-Path -Path 'variable:\ProxyAddress'
    )
    {
            $Proxy = [System.Net.WebProxy]::new( $ProxyAddress )

        If
        (
            Test-Path -Path 'variable:\ProxyPassword'
        )
        {
            $ProxyPasswordSecure = ConvertTo-SecureString -String $ProxyPassword -AsPlainText -Force
            $ProxyCredentialParam = @( $ProxyUserName, $ProxyPasswordSecure )

            $ObjectParam = @{

                TypeName     = 'System.Management.Automation.psCredential'
                ArgumentList = $ProxyCredentialParam
            }

            $ProxyCredential = New-Object @ObjectParam

            $Proxy.Credentials = $ProxyCredential
        }

        $HttpClientHandler.Proxy = $Proxy
    }

    $HttpClientHandler.AllowAutoRedirect = $False

    $HttpCompletionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead

    If
    (
        -Not ( Test-Path -Path $Destination )
    )
    {
        [System.Void]( New-Item -Path $Destination -ItemType 'Directory' )
    }

    $Count = 1

    $Uri | ForEach-Object -Process {

        Write-Verbose -Message "File $Count of $($Uri.Count)"

      # Check for redirects. We need the final URL to figure out the File Name.
 
      # We do not want to use “Invoke-WebRequest” here because it will immediately
      # download the whole thing, and we need to know the destination file name
      # first.

        $HttpClient = [System.Net.Http.HttpClient]::new( $HttpClientHandler )

        $Response = $HttpClient.GetAsync( $PSItem, $HttpCompletionOption )

        Switch
        (
            $Response.Result.StatusCode
        )
        {
            {
                $PSItem -eq 'Found' -or
                $PSItem -eq 'Redirect'        
            }
            {
                $UriCurrent = $Response.Result.Headers.Location.OriginalString
            }
                
            'OK'
            {
                $UriCurrent = $Response.Result.RequestMessage.RequestUri.OriginalString
            }
    
            Default
            {
                Write-Warning -Message 'Unknown Status code!'
            }    
        }

        Write-Verbose -Message "Downloading from `“$UriCurrent`”"
    
      # Determine the File Name

        If
        (
            $Response.Result.Content.Headers.Contains( 'Content-Disposition' ) -and
            $Response.Result.Content.Headers.ContentDisposition.FileName
        )
        {    
            $FileName = $Response.Result.Content.Headers.ContentDisposition.FileName.Trim( '"' )
        }
        Else
        {
            $FileName = [System.IO.Path]::GetFileName( $UriCurrent )
        }

        Write-Verbose -Message "File name `“$FileName`”"

        $OutFile  = Join-Path -Path $Destination -ChildPath $FileName

      # Download the whole thing

        $RequestParam = @{

            Uri                = $UriCurrent
            OutFile            = $OutFile
            UseBasicParsing    = $True
            Verbose            = $False
        }

        If
        (            
            Test-Path -Path 'variable:\ProxyAddress'
        )
        {
            $RequestParam.Add( 'Proxy', $ProxyAddress )

            If
            (
                Test-Path -Path 'variable:\ProxyCredential'
            )
            {
                $RequestParam.Add( 'ProxyCredential', $ProxyCredential )
            }
        }

        $Request  = Invoke-WebRequest @RequestParam

        $Count++
    }

#endregion Code