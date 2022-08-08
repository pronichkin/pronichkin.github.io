Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Retrieve list of galleries from ImageFap collection (“organizer”)
    or user profile (“uncategorized”)
#>

Function
Get-ifCollection
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.KeyValuePair[   # collection
            System.String,                          #   title
            System.Collections.Generic.List[        #   galleries
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
      # Collection or profile address
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

                        $gallery = [System.Collections.Generic.List[System.Uri]]::new()
                        $done    = $false

                        while
                        (
                           -not $done
                        )
                        {
                          # Figure page number

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

                            Write-Message -Channel 'Verbose' -Message "Page $page"

                          # Load gallery list

                            $list    = $false
                            $count   = 0

                            while
                            (
                               -not $list -and
                                $count -le 10
                            )
                            {
                                if
                                (
                                    $count
                                )
                                {
                                    Write-Message -Channel 'Debug' -Message "retry $count" -Indent 1

                                    $Driver.Navigate().Refresh()
                                }

                                $by      = [OpenQA.Selenium.By]::CssSelector( '.blk_galleries.expp' )
                                $list = $Driver.FindElements( $by )

                                $count++
                            }

                            Write-Message -Channel 'Debug' -Message "$($list.Count) links"

                          # Parse gallery list

                            $count = 0

                            $list | ForEach-Object -Process {

                                $uri = $psItem.GetProperty( 'href' )

                                Write-Message -Channel 'Debug' -Message $uri.AbsolutePath -Indent 1

                                if
                                (
                                    $psItem.GetAttribute( 'style' )
                                )
                                {
                                    $title = $psItem.Text

                                    Write-Message -Channel 'Debug' -Message 'This is a title' -Indent 2
                                }
                                else
                                {
                                    $gallery.Add( $uri )

                                    $count++
                                }
                            }

                            Write-Message -Channel 'Verbose' -Message "$count galleries"

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
                                $done = $true
                            }
                        }

                        Write-Message -Channel 'Verbose' -Message 'Done loading galleries'
                        
                   #endregion Load from the Internet

                   #region Build return collection

                        if
                        (
                           Test-Path -Path 'variable:\title'
                        )
                        {
                          # this is an “organizer” collection
                        }
                        else
                        {
                          # this is “uncategorized” list from a user profile

                            $title = $id
                        }

                        $return = [System.Collections.Generic.KeyValuePair[
                            System.String,
                            System.Collections.Generic.List[
                                System.Uri
                            ]
                        ]]::new( $title, $gallery )

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

                    $value = [System.Collections.Generic.LinkedList[System.Uri]]::new()

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