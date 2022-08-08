Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Save entire collection
#>

Function
Save-ifCollection
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
            'Collection'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'Pipeline',
            ValueFromPipeline               = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.KeyValuePair[   # collection
            System.String,                          #   title
            System.Collections.Generic.List[        #   galleries
                System.Uri                          #     address
            ]
        ]]
      # Metadata of the Collection to download, produced by “Get-ifCollection”
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
      # Name of the Collection to download
        $Key
    ,
        [System.Management.Automation.AliasAttribute(
            'Gallery'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory                       = $True,
            ParameterSetName                = 'PipelineByPropertyName',
            ValueFromPipelineByPropertyName = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.List[           #   galleries
            System.Uri                              #     address
        ]]
      # Gallery to download
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
                $name    = $input.Key.Trim()
                $gallery = $input.Value
            }

            'PipelineByPropertyName'
            {
                $name    = $Key.Trim()
                $gallery = $Value
            }

            default
            {
                throw 'Unknown parameter set'
            }
        }

        $pathCurrent = Join-Path -Path $Path.FullName -ChildPath $name

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
    
        return $gallery | Get-ifGallrey -Driver $Driver -Path $destination -IncludeId | Save-ifGallrey -Driver $Driver -Path $destination -Force:$Force
    }
}