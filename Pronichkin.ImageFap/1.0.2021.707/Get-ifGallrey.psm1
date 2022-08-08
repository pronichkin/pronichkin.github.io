Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Retrieve list of galleries from a collection with associated images
#>

Function
Get-ifGallrey
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.KeyValuePair[    # gallery
            System.String,                           #   title
            System.Collections.Generic.Dictionary[   #   items
                System.Uri,                          #     address
                System.String                        #     file name
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
      # Gallery address
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Include numeric Gallery ID in the metadata name. Helps avoid duplicates
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

                        $item     = [System.Collections.Generic.Dictionary[
                            System.Uri,
                            System.String
                        ]]::new()

                        $by       = [OpenQA.Selenium.By]::Id( 'menubar' )
                        $Title    = $Driver.FindElements( $by )[0]
                        $Title    = $Title[0].Text.Split( "`n" )[0].Trim()

                        if
                        (
                            $IncludeId
                        )
                        {
                         <# $by = [OpenQA.Selenium.By]::Id( 'galleryid_input' )
                            $id = $Driver.FindElements( $by )

                            $title = $title + ' — ' + $id[0].GetAttribute( 'value' )  #>

                            $title = $title + ' — ' + $id
                        }

                        Write-Message -Channel 'Verbose' -Message "Gallery: `“$Title`”"

                        $Done               = $False       

                        while
                        (
                           -not $Done
                        )
                        {
                          # Figure page number

                            $by = [OpenQA.Selenium.By]::LinkText( ':: prev ::' )

                            if
                            (
                                $Driver.FindElements( $by )
                            )
                            {
                                [System.Uri]$uriCurrent                                    = $Driver.Url
                                [System.Collections.Specialized.NameValueCollection]$query = [System.Web.HttpUtility]::ParseQueryString( $uriCurrent.Query )
                                [System.Int32]$page                                        = [System.Int32]$query[ 'page' ] + 1
                            }
                            else
                            {
                                [System.Int32]$page = 1
                            }

                            Write-Message -Channel 'Verbose' -Message "Page $page" -Indent 1

                          # Load gallery list

                            $entry = $False
                            $count = 0

                            while
                            (
                               -not $entry
                            )
                            {
                                if
                                (
                                    $count
                                )
                                {
                                    Write-Message -Channel 'Debug' -Message "retry $Count" -Indent 1

                                    $Driver.Navigate().Refresh()
                                }

                                $by      = [OpenQA.Selenium.By]::Id( 'gallery' )
                                
                                $gallery = $False
                                $count2  = 0

                                while
                                (
                                   -not $gallery
                                )
                                {
                                    if
                                    (
                                        $count2
                                    )
                                    {
                                        Write-Message -Channel 'Debug' -Message "retry2 $Count" -Indent 1

                                        Start-Sleep -Seconds 1
                                    }

                                    $gallery = $Driver.FindElements( $by )

                                    $count2++
                                }

                                $by      = [OpenQA.Selenium.By]::TagName( 'td' )
                                $entry   = $gallery[0].FindElements( $by ) |
                                    Where-Object -FilterScript { $psItem.GetAttribute( 'id' ) }

                             <# $by    = [OpenQA.Selenium.By]::ClassName( 'expp' )
                              # $Image = $Driver.FindElementsByClassName( 'expp' )
                                $Image = $Driver.FindElements( $by )

                                $by    = [OpenQA.Selenium.By]::TagName( 'img' )

                                $Image = $Image | Where-Object -FilterScript {
                                  # $psItem.FindElementsByTagName( 'img' )
                                    $psItem.FindElements( $by )
                                }  #>

                                $count++
                            }

                            Write-Message -Channel 'Debug' -Message "$(@($entry).Count) items" -Indent 1

                          # Parse gallery list

                            $count = 0

                            $entry | ForEach-Object -Process {

                                $by                  = [OpenQA.Selenium.By]::TagName( 'a' )
                                [System.Uri]$uri     = $psItem.FindElements( $by )[0].GetProperty( 'href' )

                                $by                  = [OpenQA.Selenium.By]::TagName( 'i' )
                                [System.String]$name = $psItem.FindElements( $by )[0].Text

                                Write-Message -Channel 'Debug' -Message "$($uri.AbsolutePath)  →  $name" -Indent 2

                                $item.Add( $uri, $name )

                                $count++
                            }

                            Write-Message -Channel 'Verbose' -Message "$count images" -Indent 2

                          # Navigate

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
                        }

                        Write-Message -Channel 'Debug' -Message "$page pages total"

                        Write-Message -Channel 'Verbose' -Message "$( $item.Count ) images total"

                   #endregion Load from the Internet

                   #region Build return collection

                        $return = [System.Collections.Generic.KeyValuePair[
                            System.String,
                            System.Collections.Generic.Dictionary[
                                System.Uri,
                                System.String                                
                            ]
                        ]]::new( $title, $item )

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

                    $value = [System.Collections.Generic.Dictionary[System.Uri, System.String]]::new()

                    $import.Value.GetEnumerator() | ForEach-Object -Process {
                        $value.Add( $psItem.Key, $psItem.Value )
                    }

                    $return = [System.Collections.Generic.KeyValuePair[
                        System.String,
                        System.Collections.Generic.Dictionary[
                            System.Uri,
                            System.String
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