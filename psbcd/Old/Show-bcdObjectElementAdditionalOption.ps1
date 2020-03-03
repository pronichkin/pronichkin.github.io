Using Module '.\ElementType.psm1'
Using Module '.\DeviceType.psm1'

<#
    Formats value of “Additional Options” property for meaningful display
    
    Note

    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdObjectElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Get-bcdObjectElementAdditionalOption
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
                    $Item  = Get-Item -Path $Element.StoreFilePath
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
                $Object  = Get-bcdObject -Store $Store -Id $Device.AdditionalOptions
                $Element = Get-bcdObjectElement -Object $Object
              # $Value   = Show-bcdObjectElement -Element $Element
              
                $Value   = $Element
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