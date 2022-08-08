Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Retrieve metadata for a single gallery item
#>

Function
Get-ifItem
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.KeyValuePair[    # file
            System.String,                           #   name
            System.Uri                               #   address
        ]]
    )]

    param
    (
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet',
            Mandatory         = $True
        )]
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet and Disk',
            Mandatory         = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [OpenQA.Selenium.Edge.EdgeDriver]
      # Selenium WebDriver
        $Driver
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Disk',
            Mandatory         = $True
        )]
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet and Disk',
            Mandatory         = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Directory to store locally saved metadata
        $Path
    ,
        [System.Management.Automation.AliasAttribute(
            'Address'
        )]
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet',
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet and Disk',
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Disk',
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # Page address
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet and Disk'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Load from the Internet even if locally saved metadata exists
        $Force
    )

    process
    {
        $id = $InputObject.Segments[2].Trim( '/' )

        switch
        (
            $psCmdlet.ParameterSetName
        )
        {
          # Build the on-disk file path
            {
                $psItem -in @(
                    'From Disk'
                    'From Internet and Disk'
                )
            }
            {
                $savePath = Join-Path -Path $Path.FullName -ChildPath "$id.xml"
            }
            
          # Load from the Internet and build return collection
            {
                $psItem -in @(
                    'From Internet'
                    'From Internet and Disk'
                )
            }
            {
                if
                (
                    $Force    -or
                   -not $Path -or
                    (
                        $Path -and
                       -not ( Test-Path -Path $savePath )
                    )
                )
                {
                    if
                    (
                        $Force
                    )
                    {
                        Write-Message -Channel 'Verbose' -Message "Overwriting local path `“$savePath`”, loading from the Internet"
                    }
                    elseif
                    (
                       -not $Path
                    )
                    {
                        Write-Message -Channel 'Verbose' -Message "Local path not specified, loading from the Internet"
                    }
                    elseif
                    (
                       -not ( Test-Path -Path $savePath )
                    )
                    {
                        Write-Message -Channel 'Verbose' -Message "Local path `“$savePath`” not found, loading from the Internet"
                    }
                    else
                    {
                        Write-Message -Channel 'Warning' -Message 'Unexpected condition 1'
                    }

                   #region Load from the Internet

                        $InputObject | Show-ifPage -Driver $Driver

                        $by          = [OpenQA.Selenium.By]::XPath( '//meta[@name=''description'']' )
                        $description = $Driver.FindElements( $by )[0].GetProperty( 'content' )

                        $index       = $Description.IndexOf( ' porn pic uploaded by ' )
                        $name        = $Description.Substring( '14', $Index-14 )

                        $by          = [OpenQA.Selenium.By]::Id( 'navigation' )
                        $navigation  = $Driver.FindElements( $by )

                        if
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

                            [System.Uri]$uri = $img[0].GetProperty( 'src' )

                            $return = [System.Collections.Generic.KeyValuePair[
                                System.String,
                                System.Uri
                            ]]::new( $name, $uri )
                        }

                   #endregion Load from the Internet

                   #region Build return collection

                        $return = [System.Collections.Generic.KeyValuePair[
                            System.String,
                            System.Uri
                        ]]::new( $name, $uri )

                   #endregion Build return collection
                }
                else
                {
                    Write-Message -Channel 'Verbose' -Message "Saved metadata `“$savePath`” exists, skip loading from the Internet"
                }                
            }
            
          # Save to disk
            {
                $psItem -in @(
                    'From Internet and Disk'
                )
            }
            {
                if
                (
                    $Force -or
                   -not ( Test-Path -Path $savePath )
                )
                {
                    Write-Message -Channel 'Verbose' -Message "Saving `“$savePath`” to disk"

                    Export-Clixml -InputObject $return -Path $savePath
                }
                else
                {
                    Write-Message -Channel 'Verbose' -Message "Saved metadata `“$savePath`” exists, skip saving"
                }  
            }

          # Load from disk
            {
                $psItem -in @(
                    'From Disk'
                    'From Internet and Disk'
                )
            }
            {
                if
                (
                   -not $Force -and
                    ( Test-Path -Path $savePath )
                )
                {
                    Write-Message -Channel 'Verbose' -Message "Loading from disk"

                    $import = Import-Clixml -Path $savePath

                    $return = [System.Collections.Generic.KeyValuePair[
                        System.String,
                        System.Uri
                    ]]::new( $import.Key, $import.Value )
                }
                elseif
                (
                    $Force
                )
                {
                    Write-Message -Channel 'Verbose' -Message "Overriding, skip loading from disk"
                }
                elseif
                (
                   -not ( Test-Path -Path $savePath )
                )
                {
                    throw "Could not locate $savePath"
                }
                else
                {
                    Write-Message -Channel 'Warning' -Message 'Unexpected condition 2'
                }
            }

            default
            {
                throw 'Unknown parameter set'
            }
        }

        return $return
    }
}