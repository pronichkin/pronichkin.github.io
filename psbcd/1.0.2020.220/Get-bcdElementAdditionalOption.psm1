Using Module '.\ElementType.psm1'
Using Module '.\DeviceType.psm1'

<#
    Formats value of “Additional Options” property for meaningful display
    
    Note

    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Get-bcdElementAdditionalOption
{
    [CmdletBinding()]

    Param(

        [Parameter(
            ParameterSetName  = 'Device',
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Device
    ,
        [Parameter(
            ParameterSetName  = 'Element',
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Element
    ,

      # Expand known values, recursively, and add helpful metadata

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Expand
    ,

      # Format for human-readable output

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Format
    )

    Begin
    {
     <# If “Element” was specified, it can be used to retreive additional
        options (e.g. referenced objects.) This is typically not the
        case for “Parent” object because you cannot run additional queries
        for it  #>

        Switch
        (
            $psCmdLet.ParameterSetName
        )
        {
            'Element'
            {
                $Device = $Element.Device

                If
                (
                    $Element.StoreFilePath
                )
                {
                 <# WMI format:
                    \??\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd
                    File system format:
                    \\?\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd

                    Because we obtained path from properties of WMI object and will use
                    it in a standard PowerShell cmdlet, we need to convert from former
                    into the latter.

                    Note that it won't be needed if the path is rooted to a drive letter
                  #>

                    $Path  = $Element.StoreFilePath.Replace( '\??\', '\\?\' )
                  # .Replace( '\??\', [System.String]::Empty )
                    $Item  = Get-Item -Path $Path
                    $Store = Get-bcdStore -File $Item
                }
                Else
                {
                    $Store = Get-bcdStore
                }
            }
        }
    }

    Process
    {
        If
        (
            $Device.AdditionalOptions
        )
        {
            If
            (
                $Element
            )
            {
                $ObjectParam = @{

                    Store  = $Store
                    Id     = $Device.AdditionalOptions
                    Expand = $Expand
                    Format = $Format
                }
                $Value = Get-bcdObject @ObjectParam
            }
            Else
            {
                $Message = 'Additional Options value is populated, however the Element was not specified. Unable to obtain object'
                Write-Warning -Message $Message

                $Value = $Null
            }
        }
        Else
        {
            $Value = $Null
        }
    }

    End
    {
        Return $Value
    }        
}