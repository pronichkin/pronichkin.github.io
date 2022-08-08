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
            ValueFromPipeline               = $True,
            ParameterSetName                = 'Pipeline'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # Page address, for interactive use in a pipeline
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Interactive'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # Page address, for interactive use with explicit parameter name
        $Address
    ,
        [System.Management.Automation.ParameterAttribute(
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
            ValueFromPipelineByPropertyName = $True,
            ParameterSetName                = 'PipelineByPropertyName'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # Page address, for use in pipeline inside “Save-ifGallrey”
        $Key
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ValueFromPipelineByPropertyName = $True,
            ParameterSetName                = 'PipelineByPropertyName'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # File name, for use in pipeline inside “Save-ifGallrey”
        $Value
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
                $address = $InputObject
            }

            'PipelineByPropertyName'
            {
                $address = $Key
                $name    = $Value
            }

            'Interactive'
            {
              # All parameters are already assigned
            }

            default
            {
                throw 'Unknown parameter set'
            }
        }
        
        if
        (
            $name
        )
        {
         <# First, check with the file name obtained from the Gallery view. If
            found, no need to open the page  #>

            $pathCurrent = Join-Path -Path $Path.FullName -ChildPath $name
        }

        if
        (
           -not $force -and
            $name      -and
            ( Test-Path -LiteralPath $pathCurrent )
        )
        {
            Write-Message -Channel 'Debug' -Message "`“$name`” already exists, skipping"
        }
        else
        {
            $address | Show-ifPage -Driver $Driver

         <# Reobtain file name because it might have been truncated in the
            Gallery view, and check again  #>

            $by          = [OpenQA.Selenium.By]::XPath( '//meta[@name=''description'']' )
            $description = $Driver.FindElements( $by )[0].GetProperty( 'content' )

            $index       = $Description.IndexOf( ' porn pic uploaded by ' )
            $name        = $Description.Substring( '14', $Index-14 )
            $pathCurrent = Join-Path -Path $Path.FullName -ChildPath $name

            $by          = [OpenQA.Selenium.By]::Id( 'navigation' )
            $navigation  = $Driver.FindElements( $by )

            if
            (
               -not $Force -and
                ( Test-Path -LiteralPath $pathCurrent )
            )
            {
                Write-Message -Channel 'Debug' -Message "`“$name`” already exists, skipping"
            }
            elseif
            (
                $navigation              -and
                $navigation[0].Displayed -and
                $navigation[0].Text -eq 'This gallery is empty.'
            )
            {
                Write-Message -Channel 'Warning' -Indent 1 -Message "`“$name`” $($navigation[0].Text)"
            }
            else
            {
               #region Link

                 <# 'advance-link' does not work for files that have not loaded.
                    Handling such cases would require complex error handling.
                    Instead, we'd just obtain the link slightly differently and
                    do error handling at download attempt.

                  # $bySlideshow                    = [OpenQA.Selenium.By]::ClassName( 'advance-link' )  #>
                    $bySlideshow                    = [OpenQA.Selenium.By]::ClassName( 'slideshow'    )

                    $byImg                    = [OpenQA.Selenium.By]::TagName( 'img' )
                    [System.Int32]  $countImg = 0
                    [System.Boolean]$img      = $false

                    while
                    (
                       -not $img
                    )
                    {
                        if
                        (
                            $countImg
                        )
                        {
                            Write-Message -Channel 'Warning' -Indent 1 -Message "`“$name`” — img, retry $countImg"
                            Start-Sleep -Seconds 1
                            $Driver.Navigate().Refresh()
                        }

                        [System.Int32]  $countSlideshow = 0
                        [System.Boolean]$slideshow      = $false

                        while
                        (
                           -not $slideshow
                        )
                        {
                            if
                            (
                                $countSlideshow
                            )
                            {
                                Write-Message -Channel 'Warning' -Indent 1 -Message "`“$name`” — slideshow, retry $countSlideshow"
                                Start-Sleep -Seconds 1
                                $Driver.Navigate().Refresh()
                            }

                            [System.Collections.Generic.List[OpenQA.Selenium.iWebElement]]$slideshow = $Driver.FindElements( $bySlideshow )

                            $countSlideshow++
                        }

                        [System.Collections.Generic.List[OpenQA.Selenium.iWebElement]]$img = $slideshow[0].FindElements( $byImg )

                        $countImg++
                    }

                    [System.Uri]$item = $img[0].GetProperty( 'src' )

               #endregion Link

               #region Download
                              
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
                        $Response = Invoke-WebRequest -Uri $item.AbsoluteUri -OutFile $pathCurrent -UseBasicParsing -PassThru -Verbose:$false
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

                        $response = $httpClient.GetAsync( $item ).Result

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
                        Write-Message -Channel 'Warning' -Message "`“$name`” $($response.ReasonPhrase)" -Indent 1
                    }
                    
               #endregion Download
            }
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