<#  This is a wrapper for “Invoke-WebRequest” with the following enhancements.

 1. Download multiple files sequentially with single command.
 2. “OutFile” can be specified as directory, in which case the actual File Name
    will be resolved from the server.
 3. You can even omit “OutFile” altogether, then we'll download to current directory.
 4. If file already exists with the same file, it will be skipped.  #>


Function
Invoke-WebRequestEx
{
    [CmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.Uri]]
        $Uri
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Uri]
        $Proxy
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $ProxyCredential
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]
        $OutFile = ( Get-Location ).ProviderPath
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Bits
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Test
    ,
        [Parameter()]
        [System.String]
        $UserAgent
    ,
        [Parameter()]
        [System.Uri]
        $Referrer
    )

    Begin
    {

      # First, enable TLS 1.2 just in case. Some clients might not enalbe it by
      # default, and some servers nowadays (e.g. GitHub) require it exclusively

        If
        (
            [System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12
        )
        {
            Write-Debug -Message 'TLS 1.2 is already enabled, we''re good'
        }
        Else
        {
            Write-Debug -Message 'Enabling TLS 1.2'

            [System.Net.ServicePointManager]::SecurityProtocol = 
        
                 [System.Net.SecurityProtocolType]::Tls12 +
                 [System.Net.ServicePointManager]::SecurityProtocol
        }

      # Load the assembly so that we can use its types

        $CrlPath = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

        $AssemblyName = @(
            'System.Net.Http.dll'
            'System.Web.dll'
        )

        $AssemblyName | ForEach-Object -Process {
            $AssemblyPath = Join-Path -Path $CrlPath -ChildPath $PSItem
            Add-Type -Path $AssemblyPath
        }

        $Request = [System.Collections.Generic.List[Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject]]::new()
    }

    Process
    {
      # Finally, loop thru the supplied URIs
    
        $Count = 1

        $Uri | ForEach-Object -Process {

            Write-Verbose -Message "$( ( Get-Date -DisplayHint Time ).DateTime )  File $Count of $( $Uri.Count )"

          # Check for redirects. We need the final URL to figure out the File Name.
 
          # We do not want to use “Invoke-WebRequest” here because it will immediately
          # download the whole thing, and we need to know the destination file name
          # and size first            

          # Prepare various requres parameters. All of these should be defined again
          # after the "HTTP Client" instance is disposed at the end of the loop.

            $HttpClientHandler = [System.Net.Http.HttpClientHandler]::new()
          # $HttpClientHandler.PreAuthenticate       = $True
          # $HttpClientHandler.UseDefaultCredentials = $True
          # $HttpClientHandler.AllowAutoRedirect     = $False

            If
            (
                $Proxy
            )
            {
                $WebProxy = [System.Net.WebProxy]::new( $Proxy )
        
                If
                (
                    $ProxyCredential
                )
                {
                    $WebProxy.Credentials = $ProxyCredential
                }
    
                $HttpClientHandler.Proxy = $WebProxy
            }            

            $HttpCompletionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead

            $HttpClient = [System.Net.Http.HttpClient]::new( $HttpClientHandler )

            If
            (
                $UserAgent
            )
            {
                $HttpClient.DefaultRequestHeaders.UserAgent.ParseAdd( $UserAgent )
            }

            If
            (
                $Referrer
            )
            {
                $HttpClient.DefaultRequestHeaders.Referrer = $Referrer
            }

            $Response = $HttpClient.GetAsync( $psItem,     $HttpCompletionOption )
                
            If
            (
                $Response.Result.StatusCode -eq 'Unauthorized'
            )
            {
                $HttpClientHandler = [System.Net.Http.HttpClientHandler]::new()

                $HttpClientHandler.UseDefaultCredentials = $True

                If
                (
                    $Proxy
                )
                {
                    $HttpClientHandler.Proxy = $WebProxy
                }

                $HttpClient = [System.Net.Http.HttpClient]::new( $HttpClientHandler )

                $Response = $HttpClient.GetAsync( $psItem, $HttpCompletionOption )
            }

            Write-Verbose -Message "  Downloading from `“$psItem`”"

            While
            (
                -Not $Response.Result
            )
            {
                Write-Warning -Message 'No result yet, retrying'
                $Response = $HttpClient.GetAsync( $psItem, $HttpCompletionOption )
            }

            Switch
            (
                $Response.Result.StatusCode
            )
            {
                {
                    $psItem -eq 'Found' -or
                    $psItem -eq 'Redirect'        
                }
                {
                    $UriCurrent = $Response.Result.Headers.Location.OriginalString

                    Write-Verbose -Message "  Redirected to    `“$UriCurrent`”"

                    $Response = $HttpClient.GetAsync( $UriCurrent, $HttpCompletionOption )
                }
                
                'OK'
                {
                    $UriCurrent = $Response.Result.RequestMessage.RequestUri.OriginalString
                }

                'Forbidden'
                {
                    Write-Error -Message "The server says `“$($Response.Result.StatusCode)`”"
                }
    
                Default
                {
                    Write-Warning -Message "  Unknown Status code `“$($Response.Result.StatusCode)`”!"
                }    
            }

          # If OutFile was specified as directory, we need to obtain the File Name
          # from the server

            If
            (
                $OutFile.Attributes -band [System.IO.FileAttributes]::Directory
            )
            {
                $Query = [System.Web.HttpUtility]::ParseQueryString( $Response.Result.RequestMessage.RequestUri.Query )

                If
                (
                    $Response.Result.Content.Headers.Contains( 'Content-Disposition' ) -and
                    $Response.Result.Content.Headers.ContentDisposition.FileName
                )
                {    
                    $FileName = $Response.Result.Content.Headers.ContentDisposition.FileName.Replace( '"', '' )
                }
                ElseIf
                (
                    $Query.AllKeys.Contains( 'response-content-disposition' )
                )
                {
                    $Disposition = $Query.Get( 'response-content-disposition' )

                    $Parse = [System.Net.Http.Headers.ContentDispositionHeaderValue]::Parse( $Disposition )

                    $FileName = $Parse.FileName.Replace( '"', '' )
                }
                Else
                {
                    $FileName = $Response.Result.RequestMessage.RequestUri.Segments[ -1 ]
                }

                $OutFileFull = Join-Path -Path $OutFile -ChildPath $FileName
            }
            Else
            {
                $FileName    = $OutFile.Name
                $OutFileFull = $OutFile.FullName
            }

            $Size = [System.Math]::Round( $Response.Result.Content.Headers.ContentLength/1mb, 2 )

            Write-Verbose -Message "  Downloading to   `“$FileName`”, $Size MB"

          # Check if the file already exists

            If
            (
                ( Test-Path -Path $OutFileFull ) -and
                ( Get-Item -Path $OutFileFull ).Length -eq $Response.Result.Content.Headers.ContentLength
            )
            {
                Write-Verbose -Message "  File `“$OutFileFull`” already exists with the same size, skipping"
            }
            ElseIf
            (
                $Bits
            )
            {        
                $Transfer = Get-BitsTransfer | Where-Object -FilterScript { $PSItem.DisplayName -eq $FileName }

                If
                (
                    $Transfer
                )
                {
                    Write-Warning -Message "  Transfer already exists"
                }
                Else
                {
                    $TransferParam = @{
                    
                        Source       = $UriCurrent
                        Destination  = $OutFileFull
                        DisplayName  = $FileName
                        Asynchronous = $True
                    }

                    If
                    (
                        $Proxy
                    )
                    {
                        $TransferParam.Add( 'ProxyList', $Proxy )

                        If
                        (
                            $ProxyCredential
                        )
                        {
                            $TransferParam.Add( 'ProxyCredential', $ProxyCredential )
                        }
                    }

                    $Transfer = Start-BitsTransfer @TransferParam
                    $Transfer = Suspend-BitsTransfer -BitsJob $Transfer

                    If
                    (
                        $Query.AllKeys.Contains( 'validfrom' )
                    )
                    {
                        $Created     = [System.DateTimeOffset]::FromUnixTimeSeconds( $Query.Get( "validfrom" ) )
                        $Expire      = [System.DateTimeOffset]::FromUnixTimeSeconds( $Query.Get( "validto"   ) )

                        Write-Verbose -Message $Url.Segments[ -3 ]
                        Write-Verbose -Message "Link valid from $( $Created.LocalDateTime )"
                        Write-Verbose -Message "Starting at     $( $Transfer.CreationTime )"
                        Write-Verbose -Message "Link expires at $( $Expire.LocalDateTime )"
                    }
                    Else
                    {
                        Write-Verbose -Message '  Transfer scheduled'
                    }
                }
            }
            Else
            {        
              # Download the whole thing

                $RequestParam = @{

                    Uri                = $UriCurrent
                    OutFile            = $OutFileFull
                    UseBasicParsing    = $True
                    Verbose            = $False
                }

                If
                (
                    $Proxy
                )
                {
                    $RequestParam.Add( 'Proxy', $Proxy )

                    If
                    (
                        $ProxyCredential
                    )
                    {
                        $RequestParam.Add( 'ProxyCredential', $ProxyCredential )
                    }
                }

                $Request.Add( ( Invoke-WebRequest @RequestParam ) )
            }

            $Response.Dispose()

            $HttpClient.Dispose()
        
          # Remove-Variable -Name 'HttpClient'

            $Count++
        }
    }

    End
    {
        Return $Request
    }
}