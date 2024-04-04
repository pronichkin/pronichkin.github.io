Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Obtain file or directory at given path and name

   .DESCRIPTION
    The item will be creatd if it does not exist. Otherwise, return existing object
#>

function
Get-ItemEx
{
    [System.Management.Automation.CmdletBindingAttribute(
        DefaultParameterSetName = 'File'    
    )]

    [System.Management.Automation.OutputTypeAttribute(
        [System.IO.FileInfo],
        ParameterSetName        = 'File'
    )]

    [System.Management.Automation.OutputTypeAttribute(
        [System.IO.DirectoryInfo],
        ParameterSetName        = 'Directory'
    )]

    param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory           = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Path
        $Path
    ,
        [System.Management.Automation.AliasAttribute(
            'Name'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory           = $true,
            ValueFromPipeline   = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # Name
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory           = $false,
            ParameterSetName    = 'Directory'
        )]
        [System.Management.Automation.SwitchParameter]
      # Create a directory instead of file
      # Does not work for checking for existing one
        $Directory
    )

    begin
    {}

    process
    {
        $pathCurrent = Join-Path -Path $Path.FullName -ChildPath $InputObject

        if
        (
            Test-Path -Path $pathCurrent
        )
        {
            Get-Item -Path $pathCurrent
        }
        else
        {
            $itemParam = @{
                Path     =  $Path.FullName
                Name     =  $InputObject                
            }

            if
            (
                $Directory
            )
            {
                $itemParam.Add( 'ItemType', 'Directory' )

            }

            New-Item @itemParam
        }
    }

    end
    {}
}