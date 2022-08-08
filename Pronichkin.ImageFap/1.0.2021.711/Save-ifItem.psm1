Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Save images from a gallery
#>

Function
Save-ifItem
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.IO.FileInfo]
    )]

    param(
    
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [OpenQA.Selenium.Edge.EdgeDriver]
      # Selenium WebDriver
        $Driver
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Interactive'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # File name to optionally check if file already exists, for interactive
      # use with explicit parameter name
        $Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Interactive'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # File address, for interactive use with explicit parameter name
        $Address
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ValueFromPipeline               = $True,
            ParameterSetName                = 'Pipeline'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.KeyValuePair[    # file
            System.String,                           #   name
            System.Collections.Generic.List[
                System.Uri                           #   address
            ]                                        
        ]]
      # Value pair for use in pipeline inside “Save-ifGallrey”
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Destination folder, default to current location
        $Path = ( Get-Item -Path '.' )
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Overwrite existing files
        $Force
    )

    begin
    {
        $httpClient = [System.Net.Http.HttpClient]::new()
    }

    process
    {
        switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            'Pipeline'
            {
                $name    = $InputObject.Key

                if
                (
                    $InputObject.Value
                )
                {
                    $addressCurrent = $InputObject.Value[0]
                }
                elseif
                (
                    Test-Path -Path 'variable:\addressCurrent'
                )
                {
                    Remove-Variable -Name 'addressCurrent'
                }
            }

            'Interactive'
            {
              # All parameters are already assigned

                $addressCurrent = $Address
            }

            default
            {
                throw 'Unknown parameter set'
            }
        }

      # Remove invalid path characters (such as “:” or “/”) from file name

        [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object -Process {
            $name = $name.Replace( $psItem.toString(), [System.String]::Empty )
        }

        $pathCurrent = Join-Path -Path $Path.FullName -ChildPath $name

        if
        (
           -not $force -and
            ( Test-Path -LiteralPath $pathCurrent )
        )
        {
            Write-Message -Channel 'Debug' -Message "`“$name`” already exists, skipping"
        }
        elseif
        (
            ( Test-Path -Path 'variable:\addressCurrent' ) -and $addressCurrent
        )
        {
         <# ImageFap picture deeplinks are time-based and expire over time. If
            the metadata was obtained too long ago, the download link becomes
            stale and is no longer valid. In this case, we need to re-query for
            the link using the original image address (that is, not the deep
            link used for saving)  #>

            [System.Collections.Specialized.NameValueCollection]$query = [System.Web.HttpUtility]::ParseQueryString( $addressCurrent.Query )

            $end = [System.DateTimeOffset]::FromUnixTimeSeconds( $query[ 'end' ] )

            if
            (
                $end -lt [System.DateTime]::Now
            )
            {
                Write-Message -Channel 'Warning' -Message "`“$name`” address expired, regenerating"
            
              # clean up the old metadata saved to disk

                $id = [System.IO.FileInfo]::new( $addressCurrent.AbsolutePath ).BaseName

                $savePath = Join-Path -Path $Path.FullName -ChildPath "$id.xml"

                if
                (
                    Test-Path -LiteralPath $savePath
                )
                {
                    Remove-Item -LiteralPath $savePath
                }

              # obtain the new metadata

                $addressCurrent = [System.Uri]::new( "https://www.imagefap.com/photo/$id" )

                $InputObject = $addressCurrent | Get-ifItem -Driver $Driver -Path $Path

                $addressCurrent = $InputObject.Value[0]
            }

         <# Invoke-WebRequest has a couple of issues which prevent us from
            using it here.

             1. It only generates terminating errors, regarless of ErrorAction
                https://github.com/PowerShell/PowerShell/issues/4534

             2. It treats -OutFile parameter as 'Path' instead of a 'Literal
                Path' and hence makes it impossible to use paths with
                characters like `[ or `]
                https://github.com/PowerShell/PowerShell/issues/3174
    
         <# $response = $null
            $count    = 0
              
            $pathCurrent = [System.Management.Automation.WildcardPattern]::Escape( $pathCurrent )

            while
            (
               -not $Response
            )
            {
                if
                (
                    $count
                )
                {
                    Write-Message -Channel 'Warning' -Message "`“$name`” attempt $count" -Indent 1
                    Start-Sleep -Seconds 1
                }

                try
                {
                    $Response = Invoke-WebRequest -Uri $addressCurrent.AbsoluteUri -OutFile $pathCurrent -UseBasicParsing -PassThru -Verbose:$false
                }
                catch
                {
                    if
                    (
                        $psItem.Exception -is [System.Net.WebException]
                    )
                    {
                        $Response = $psItem.Exception.Response
                    }
                    else
                    {
                        Write-Message -Channel 'Warning' -Message $psItem.Exception.GetType().FullName
                    }
                }
            }

         <# In case of success, Invoke-WebRequest returns an object of
            [Microsoft.PowerShell.Commands.WebResponseObject] which contains
           “StatusCode” as [System.Int32]. In case of failure, the
            Exception.Response is [System.Net.HttpWebResponse] where
           “StatusCode” is [System.Net.HttpStatusCode]. Hence we need to
            convert them to the same type before extracting value  #>

            $count    = 0
            $response = $false

            while
            (
              -not ( $response -and $response.IsSuccessStatusCode ) -and
               $count -le 5
            )
            {
                if
                (
                    $count
                )
                {
                    Write-Message -Channel 'Warning' -Message "`“$name`” download retry $count" -Indent 1
                    Start-Sleep -Seconds 3
                }

                $response = $httpClient.GetAsync( $addressCurrent ).Result

                $count++
            }

            if
            (
                $response.IsSuccessStatusCode
            )
            {
                Write-Message -Channel 'Debug'   -Message "`“$name`” $($response.ReasonPhrase)"

                $streamParam = @(
                  # https://docs.microsoft.com/dotnet/api/system.io.filestream.-ctor?view=netframework-4.8#System_IO_FileStream__ctor_System_String_System_IO_FileMode_System_IO_FileAccess_
                    $pathCurrent,                   # path
                    [System.IO.FileMode]::Create,   # mode
                    [System.IO.FileAccess]::Write   # access
                )
                $file     = [System.IO.FileStream]::new.Invoke( $streamParam )

                $download = $response.Content.ReadAsStreamAsync().Result
                $download.CopyTo( $file )
                
                $download.Close()
                $file.Close()
            }
            else
            {
                Write-Message -Channel 'Warning' -Message "`“$name`” $($response.ReasonPhrase), $($addressCurrent.AbsoluteUri)" -Indent 1
            }
        }
        else
        {
            Write-Message -Channel 'Warning' -Message "`“$name`” no address provided" -Indent 1
        }

        if
        (
            Test-Path -LiteralPath $pathCurrent
        )
        {
            return Get-Item -LiteralPath $pathCurrent
        }
    }

    end
    {
        $httpClient.Dispose()
    }
}