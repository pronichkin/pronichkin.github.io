Function
Invoke-WebRequestEx
{
    [CmdletBinding()]

    Param(
    
        [Parameter()]
        [System.Collections.Generic.List[System.Uri]]
        $Uri
    ,
        [Parameter()]
        [System.IO.DirectoryInfo]
        $Directory
    ,
        [Parameter()]
        [System.Uri]
        $Proxy
    ,
        [Parameter()]
        [System.Management.Automation.psCredential]
        $ProxyCredential
    ,
        [Parameter()]
        [System.String]
        $UserAgent
    )

    Begin
    {
        If
        (
            [System.Net.ServicePointManager]::SecurityProtocol -notlike '*tls12*'
        )
        {
            [System.Net.ServicePointManager]::SecurityProtocol = 
        
                 [System.Net.SecurityProtocolType]::Tls12 +
                 [System.Net.ServicePointManager]::SecurityProtocol
        }

        $CrlPath      = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $AssemblyName = 'System.Net.Http.dll'
        $AssemblyPath = Join-Path -Path $CrlPath -ChildPath $AssemblyName
        Add-Type -Path $AssemblyPath
    
        $HttpClientHandler = [System.Net.Http.HttpClientHandler]::new()    

        If
        (
            $Proxy
        )
        {
            $Proxy = [System.Net.WebProxy]::new( $ProxyAddress )

            If
            (
                $ProxyCredential
            )
            {
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

        $Request = [System.Collections.Generic.List[Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]]::new()
    }

    Process
    {
        $Count = 1

        $Uri | ForEach-Object -Process {

            Write-Verbose -Message "File $Count of $($Uri.Count)"

            [System.Uri]$UriCurrent = $psItem

          # Check for redirects. We need the final URL to figure out the File Name.
 
          # We do not want to use “Invoke-WebRequest” here because it will immediately
          # download the whole thing, and we need to know the destination file name
          # first.

            $HttpClient = [System.Net.Http.HttpClient]::new( $HttpClientHandler )

            If
            (
                $UserAgent
            )
            {
                $HttpClient.DefaultRequestHeaders.UserAgent.ParseAdd( $UserAgent )
            }

            $HttpClient.DefaultRequestHeaders.Referrer = [System.Uri]'https://membersv2.evilangel.com/en/video//bts-squirting-adriana%3A-gaping-anal%2Fswallow/148296'

            $Response = $HttpClient.GetAsync( $UriCurrent, $HttpCompletionOption )

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
                    $Message = "Unexpected status code: `“$($Response.Result.StatusCode)`”"

                    Write-Warning -Message $Message
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
                PassThru           = $False
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

            $Request += Invoke-WebRequest @RequestParam

            $Count++
        }
    }

    End
    {
        Return $Request
    }
}