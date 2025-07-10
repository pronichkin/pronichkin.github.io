Using Module '.\ElementType.psm1'
Using Module '.\DeviceType.psm1'

<#
   .Synopsis
    Formats value of “Additional Options” property for meaningful display

   .Detail

    Additional options can be populated for “Partition”, “Qualified Partition”
    and “RAM disk” device types. They provide a reference (GUID) to a different
    BCD object. This cmdlet returns such object, hence providing an option to
    populate objects recursively (i.e. populate referenced object instead of
    its GUID in referencing object.)
    
   .Note
    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Get-bcdElementAdditionalOption
{
    [System.Management.Automation.CmdletBindingAttribute(
        HelpURI           = 'https://pronichkin.com',
        PositionalBinding = $false
    )]

    param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            HelpMessage       = 'https://learn.microsoft.com/previous-versions/windows/desktop/bcd/bcdDeviceElement',
            ParameterSetName  = 'Element',            
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.AliasAttribute(
            'Element'
        )]
        [System.Management.Automation.psTypeNameAttribute(
            'Microsoft.Management.Infrastructure.CimInstance#root/wmi/bcdDeviceElement'
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            HelpMessage       = 'https://learn.microsoft.com/previous-versions/windows/desktop/bcd/bcdDeviceData',
            ParameterSetName  = 'Device',            
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.psTypeNameAttribute(
            'Microsoft.Management.Infrastructure.CimInstance#root/wmi/bcdDeviceData'
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Device
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            HelpMessage       = 'Expand known values, recursively, and add helpful metadata'
        )]
        [System.Management.Automation.SwitchParameter]
        $Expand
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            HelpMessage       = 'Format for human-readable output'
        )]
        [System.Management.Automation.SwitchParameter]
        $Format
    )

    begin
    {}

    process
    {
     <# If “Element” was specified (as “Input object”), it can be used to
        retreive additional options (e.g., referenced objects.) This is
        typically not the case for “Parent” object because you cannot run
        additional queries for it.  #>

        switch
        (
            $psCmdLet.ParameterSetName
        )
        {
            'Element'
            {
              # device is the property we're going evaluate
                $Device = $InputObject.Device

              # store is needed for additional queries
                if
                (
                    $InputObject.StoreFilePath
                )
                {
                 <# WMI format:
                    \??\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd
                    File system format:
                    \\?\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd

                    Because we obtained path from properties of WMI object and
                    will use it in a standard PowerShell cmdlet, we need to
                    convert from former into the latter.

                    Note that it won't be needed if the path is rooted to a
                    drive letter.  #>

                    $path  = $InputObject.StoreFilePath.Replace( '\??\', '\\?\' )
                    $item  = Get-Item -Path $path
                    $store = Get-bcdStore -File $item
                }
                else
                {
                    $Store = Get-bcdStore
                }
            }
        }

        if
        (
            $Device.AdditionalOptions
        )
        {
            if
            (
                $InputObject
            )
            {
                $objectParam = @{
                    Store  = $store
                    Id     = $Device.AdditionalOptions
                    Expand = $Expand
                    Format = $Format
                }
                $value = Get-bcdObject @objectParam
            }
            else
            {
                $message = 'Additional Options value is populated, however the Element was not specified. Unable to obtain object'
                Write-Warning -Message $message

                $value = $null
            }
        }
        else
        {
            $value = $null
        }

        return $value
    }

    end
    {}        
}