Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Retrieve list of child items from ImageFap collection (“organizer”, gallery or page)
    or user profile (“uncategorized”)
#>

Function
Get-ifItem
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.KeyValuePair[   # item (organizer|gallery|page)
            System.String,                          #   name
            System.Collections.Generic.List[        #   members (galleries|pages|image)
                System.Uri                          #     address
            ]
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
      # Item address
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Include itm ID in the metadata name. Helps avoid duplicates
        $IncludeId
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'From Internet and Disk'
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Load from the Internet even if locally saved metadata exists
        $Force
    )

    begin
    {
      # Needed to use [System.Web.HttpUtility]

        $runtime  = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $runtime  = Join-Path -Path $runtime -ChildPath 'System.Web.dll'  # System.Web.Services.dll
        $assembly = [System.Reflection.Assembly]::LoadFrom( $runtime )
    }

    process
    {
        $type = $InputObject.Segments[1].Trim( '/' )
        $id   = $InputObject.Segments[2].Trim( '/' )
        
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

                        $item = [System.Collections.Generic.List[
                            System.Uri
                        ]]::new()

                        switch
                        (
                            $type
                        )
                        {
                            {
                                $psItem -in @(
                                  # 'organizer'  # collection
                                  # 'profile'    # uncategorized
                                    'pictures'   # gallery
                                  # 'photo'      # single image
                                )
                            }
                            {
                                $by       = [OpenQA.Selenium.By]::Id( 'menubar' )
                                $name    = $Driver.FindElements( $by )[0]
                                $name    = $name[0].Text.Split( "`n" )[0].Trim()

                                Write-Message -Channel 'Verbose' -Message "Gallery title: `“$name`”"
                            }

                            {
                                $psItem -in @(
                                    'organizer'  # collection
                                    'profile'    # uncategorized
                                    'pictures'   # gallery
                                  # 'photo'      # single image
                                )
                            }
                            {
                                $done               = $False

                                while
                                (
                                   -not $done
                                )
                                {
                                   #region page number

                                        $by = [OpenQA.Selenium.By]::LinkText( ':: prev ::' )

                                        if
                                        (
                                            $Driver.FindElements( $by )
                                        )
                                        {
                                            [System.Uri]$uri                                           = $Driver.Url
                                            [System.Collections.Specialized.NameValueCollection]$query = [System.Web.HttpUtility]::ParseQueryString( $uri.Query )
                                            [System.Int32]$page                                        = [System.Int32]$query[ 'page' ] + 1
                                        }
                                        else
                                        {
                                            [System.Int32]$page = 1
                                        }

                                        Write-Message -Channel 'Verbose' -Message "Page $page" -Indent 1

                                   #endregion page number

                                   #region load

                                        $itemCurrent = $false
                                        $countItem   = 0

                                        while
                                        (
                                           -not $itemCurrent -and
                                            $countItem -le 10
                                        )
                                        {
                                            if
                                            (
                                                $countItem
                                            )
                                            {
                                                Write-Message -Channel 'Debug' -Message "retry Item $countItem" -Indent 1

                                                $Driver.Navigate().Refresh()
                                            }

                                            switch
                                            (
                                                $type
                                            )
                                            {
                                                {
                                                    $psItem -in @(
                                                        'organizer'  # collection
                                                        'profile'    # uncategorized
                                                      # 'pictures'   # gallery
                                                    )
                                                }
                                                {
                                                    $by          = [OpenQA.Selenium.By]::CssSelector( '.blk_galleries.expp' )
                                                    $itemCurrent = $Driver.FindElements( $by )
                                                }

                                                {
                                                    $psItem -in @(
                                                      # 'organizer'  # collection
                                                      # 'profile'    # uncategorized
                                                        'pictures'   # gallery
                                                    )
                                                }
                                                {
                                                    $by           = [OpenQA.Selenium.By]::Id( 'gallery' )
                                
                                                    $gallery      = $False
                                                    $countGallery = 0

                                                    while
                                                    (
                                                       -not $gallery
                                                    )
                                                    {
                                                        if
                                                        (
                                                            $countGallery
                                                        )
                                                        {
                                                            Write-Message -Channel 'Debug' -Message "retry Gallery $countGallery" -Indent 1

                                                            Start-Sleep -Seconds 1
                                                        }

                                                        $gallery = $Driver.FindElements( $by )

                                                        $countGallery++
                                                    }

                                                    $by          = [OpenQA.Selenium.By]::TagName( 'td' )
                                                    $itemCurrent = $gallery[0].FindElements( $by ) |
                                                        Where-Object -FilterScript { $psItem.GetAttribute( 'id' ) }

                                             <# $by    = [OpenQA.Selenium.By]::ClassName( 'expp' )
                                              # $Image = $Driver.FindElementsByClassName( 'expp' )
                                                $Image = $Driver.FindElements( $by )

                                                $by    = [OpenQA.Selenium.By]::TagName( 'img' )

                                                $Image = $Image | Where-Object -FilterScript {
                                                  # $psItem.FindElementsByTagName( 'img' )
                                                    $psItem.FindElements( $by )
                                                }  #>                                            
                                                }

                                                default
                                                {
                                                    throw 'Unknown type'
                                                }
                                            }

                                            $countItem++
                                        }

                                        Write-Message -Channel 'Debug' -Message "$(@($itemCurrent).Count) items" -Indent 1

                                   #endregion Load item

                                   #region parse

                                        $count = 0

                                        $itemCurrent | ForEach-Object -Process {

                                            switch
                                            (
                                                $type
                                            )
                                            {
                                                {
                                                    $psItem -in @(
                                                        'organizer'  # collection
                                                        'profile'    # uncategorized
                                                      # 'pictures'   # gallery
                                                    )
                                                }
                                                {
                                                    [System.Uri]$address = $psItem.GetProperty( 'href' )

                                                    Write-Message -Channel 'Debug' -Message $address.AbsolutePath -Indent 1

                                                    if
                                                    (
                                                        $psItem.GetAttribute( 'style' )
                                                    )
                                                    {
                                                        $name = $psItem.Text

                                                        Write-Message -Channel 'Debug' -Message 'This is a title' -Indent 2

                                                        Write-Message -Channel 'Verbose' -Message "Collection title: `“$name`”"
                                                    }
                                                    else
                                                    {
                                                        $item.Add( $address )

                                                        $count++
                                                    }                                                
                                                }

                                                {
                                                    $psItem -in @(
                                                      # 'organizer'  # collection
                                                      # 'profile'    # uncategorized
                                                        'pictures'   # gallery
                                                    )
                                                }
                                                {
                                                    $by                  = [OpenQA.Selenium.By]::TagName( 'a' )
                                                    [System.Uri]$address = $psItem.FindElements( $by )[0].GetProperty( 'href' )

                                                 <# $by                  = [OpenQA.Selenium.By]::TagName( 'i' )
                                                    [System.String]$name1 = $psItem.FindElements( $by )[0].Text                                                

                                                    Write-Message -Channel 'Debug' -Message "$($address.AbsolutePath)  →  $name1" -Indent 2  #>

                                                    Write-Message -Channel 'Debug' -Message $address.AbsolutePath -Indent 1

                                                  # $item.Add( $address, $name1 )
                                                    $item.Add( $address )

                                                    $count++
                                                }

                                                default
                                                {
                                                    throw 'Unknown type'
                                                }
                                            }
                                        }

                                        Write-Message -Channel 'Verbose' -Message "$count items" -Indent 2

                                   #endregion gallery list

                                   #region navigate

                                        $by = [OpenQA.Selenium.By]::LinkText( $page+1 )

                                        if
                                        (
                                            $Driver.FindElements( $by )
                                        )
                                        {
                                            $by   = [OpenQA.Selenium.By]::LinkText( ':: next ::' )
                                            $Next = $Driver.FindElements( $by )

                                          # $Next[0].Click()

                                            [System.Uri]$href = $Next[0].GetAttribute( 'href' )
                                            $href | Show-ifPage -Driver $Driver
                                        }
                                        else
                                        {
                                            $Done = $True
                                        }

                                   #endregion navigate
                                }

                                Write-Message -Channel 'Debug' -Message "$page pages total"

                                Write-Message -Channel 'Verbose' -Message "$( $item.Count ) images total"                            
                            }

                            {
                                $psItem -in @(
                                  # 'organizer'  # collection
                                  # 'profile'    # uncategorized
                                  # 'pictures'   # gallery
                                    'photo'      # single image
                                )
                            }
                            {
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

                                    [System.Uri]$address = $img[0].GetProperty( 'src' )

                                    $item.Add( $address )
                                }
                            }

                            default
                            {
                                throw 'Unknown type'
                            }
                        }

                   #endregion Load from the Internet

                   #region Build return collection

                        if
                        (
                           Test-Path -Path 'variable:\name'
                        )
                        {
                            if
                            (
                                $IncludeId
                            )
                            {
                             <# $by = [OpenQA.Selenium.By]::Id( 'galleryid_input' )
                                $id = $Driver.FindElements( $by )

                                $name = $name + ' — ' + $id[0].GetAttribute( 'value' )  #>

                                $name = $name + ' — ' + $id
                            }
                        }
                        else
                        {
                          # this is “uncategorized” list from a user profile

                            $name = $id
                        }

                        $return = [System.Collections.Generic.KeyValuePair[
                            System.String,
                            System.Collections.Generic.List[
                                System.Uri
                            ]
                        ]]::new( $name, $item )

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

                 <# Need to reformat Value collection after importing, otherwise
                    format won't match what was exported  #>

                    $import = Import-Clixml -Path $savePath

                    $value = [System.Collections.Generic.LinkedList[
                        System.Uri
                    ]]::new()

                    $import.Value | ForEach-Object -Process {
                        $value.Add( $psItem )
                    }

                    $return = [System.Collections.Generic.KeyValuePair[
                        System.String,
                        System.Collections.Generic.List[
                            System.Uri
                        ]
                    ]]::new( $import.Key, $value )
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