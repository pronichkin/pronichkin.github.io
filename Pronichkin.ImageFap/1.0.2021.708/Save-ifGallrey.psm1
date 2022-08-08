Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Save entire gallery
#>

Function
Save-ifGallrey
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.List[
            System.IO.FileInfo
        ]]
    )]

    param(
    
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [OpenQA.Selenium.Edge.EdgeDriver]
      # Selenium WebDriver
        $Driver
    ,
        [System.Management.Automation.AliasAttribute(
            'Gallery'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Pipeline',
            ValueFromPipeline               = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.KeyValuePair[    # gallery
            System.String,                           #   title
            System.Collections.Generic.Dictionary[   #   items
                System.Uri,                          #     address
                System.String                        #     file name
            ]
        ]]
      # Metadata of the Gallery to download, produced by “Get-ifGallery”
        $InputObject
    ,
        [System.Management.Automation.AliasAttribute(
            'Name'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'PipelineByPropertyName',
            ValueFromPipelineByPropertyName = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # Name of the gallery to download
        $Key
    ,
        [System.Management.Automation.AliasAttribute(
            'Item'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'PipelineByPropertyName',
            ValueFromPipelineByPropertyName = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.Dictionary[      #   items
            System.Uri,                              #     address
            System.String                            #     file name
        ]]
      # Items to download
        $Value
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Destination directory
        $Path
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Overwrite local files if exist
        $Force
    )

    process
    {
        switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            'Pipeline'
            {
                $name = $input.Key.Trim()
                $item = $input.Value
            }

            'PipelineByPropertyName'
            {
                $name = $Key.Trim()
                $item = $Value
            }

            default
            {
                throw 'Unknown parameter set'
            }
        }

      # Remove invalid path characters (such as `: or `/ from gellery name

        [System.IO.Path]::GetInvalidFileNameChars() | ForEach-Object -Process {
            $name = $name.Replace( $psItem.toString(), [System.String]::Empty )
        }

        $pathCurrent = Join-Path -Path $path -ChildPath $name

        if
        (
            Test-Path -LiteralPath $pathCurrent
        )
        {
            $destination = Get-Item -LiteralPath $pathCurrent
        }
        else
        {
            $destination = New-Item -Path $pathCurrent -ItemType 'Directory'
        }

        Write-Message -Channel 'Verbose' -Message $name

      # return $item.GetEnumerator() | Get-ifItem -Driver $Driver -Path $destination | Save-ifItem -Driver $Driver -Path $destination -Force:$Force

        return $item.Keys            | Get-ifItem -Driver $Driver -Path $destination | Save-ifItem -Driver $Driver -Path $destination -Force:$Force
    }
}