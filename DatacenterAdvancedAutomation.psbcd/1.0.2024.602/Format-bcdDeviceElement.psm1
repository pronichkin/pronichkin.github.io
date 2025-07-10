using Module '.\ElementType.psm1'
using Module '.\Flag.psm1'
using Module '.\DeviceType.psm1'

Import-Module -Name 'Storage' -Verbose:$False

<#
    .Synopsis
     Formats value of “Device” property for meaningful display
    
   .Note
    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Format-bcdDeviceElement
{
    [System.Management.Automation.CmdletBindingAttribute(
        HelpURI           = 'https://pronichkin.com',
        PositionalBinding = $false
    )]

    param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            HelpMessage       = 'https://learn.microsoft.com/previous-versions/windows/desktop/bcd/bcdDeviceElement',
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.psTypeNameAttribute(
            'Microsoft.Management.Infrastructure.CimInstance#root/wmi/bcdDeviceElement'
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            HelpMessage       = 'Qualified or raw'
        )]
        [System.Management.Automation.ValidateSetAttribute(
            'Qualified',
            'Raw'
        )]
        [System.String]
        $Mode
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

      # device is the property we're going evaluate
        $device = $InputObject.Device

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

            if
            (
                $InputObject.StoreFilePath.Contains( [System.IO.Path]::VolumeSeparatorChar )
            )
            {
                $path = $InputObject.StoreFilePath.Replace( '\??\', [System.String]::Empty )
            }
            else
            {
                $path  = $InputObject.StoreFilePath.Replace( '\??\', '\\?\' )
              # $path  = $InputObject.StoreFilePath.Replace( '\??\', '\\.\' )
            }
                
            $item  = Get-Item -Path $path
            $store = Get-bcdStore -File $item
        }
        else
        {
            $Store = Get-bcdStore
        }

      # building output object
        $value = @{        
            DeviceType = [BCDE_DEVICE_TYPE]$device.DeviceType
        }

        $elementParam = @{
            Expand = $Expand
            Format = $Format
        }

        switch
        (
            $device.DeviceType
        )
        {
            1  # Boot
            {
              # No more properties to populate
            }
    
            2  # Partition
            {
              # We can query for the same Element as “Qualified Partition”
              # to retrieve more information

              # retrieve parent object for current element
                $ObjectParam = @{
                    Store  = $store
                    Id     = $InputObject.ObjectId
                  # Expand = $Expand
                  # Format = $Format
                }
                $object             = Get-bcdObject @ObjectParam

              # retrieve detailed version of the current element which
              # provides information such as “Disk Signature” and “Partition
              # Identifier”
                $elementFlagParam = @{
                    Object = $Object
                    Type   = $InputObject.Type
                }

                switch
                (
                    $Mode
                )
                {
                    'Qualified'
                    {
                        $elementFlagParam.Add(
                            'Flag', [BCD_FLAGS_TYPE]::BCD_FLAGS_QUALIFIED_PARTITION
                        )
                    }

                    'Raw'
                    {
                        $elementFlagParam.Add(
                            'Flag', [BCD_FLAGS_TYPE]::BCD_FLAGS_NO_DEVICE_TRANSLATION
                        )
                    }
                }

                $elementFlag = Get-bcdElement @elementFlagParam

                switch
                (
                    $Mode
                )
                {
                    'Qualified'
                    {
                      # Microsoft.Management.Infrastructure.CimInstance#ROOT/wmi/BcdDeviceQualifiedPartitionData
                        $device = $elementFlag.Device
                    }

                    'Raw'
                    {
                      # System.Collections.Hashtable
                        $device = $elementFlag.Device.Data | Format-bcdDeviceData
                    }
                }

                $device

             <# the following code was inherited from `Get-bcdElementDevice`
                which was the previous version of `Format-bcdDeviceElement`.
                It obtains respective objects based on the IDs discovered
                above. It's not yet implemented here.

              # partition object
              # obtain the same element in a format specific to Device type
                $elementParamCurrent = $elementParam.Clone()
                $elementParamCurrent.Add( 'Device', $elementQualified.Device )

                $partitionQualified = Get-bcdElementDevice @elementParamCurrent

                $value.Add( 'Partition', $partitionQualified.Partition )

              # additional options
                $elementParam.Add( 'Element', $InputObject )

                $additionalOption = Get-bcdElementAdditionalOption @elementParam

                $value.Add( 'Additional Options'  ,  $additionalOption )
                $value.Add( 'Path'                ,  $device.Path      )

             #>
            }

            3  # File
            {
              # Not properly implemented yet, looking for real world examples

                $value.Add( 'Path'                ,  $device.Path      )
            }

            4  # Ramdisk
            {
                $elementParamCurrent = $elementParam.Clone()
                $elementParamCurrent.Add( 'Device', $device.Parent )

                $parent = Get-bcdElementDevice @elementParamCurrent

                if
                (
                    $InputObject
                )
                {
                 <# “Element” is the preferred query method because it provides
                    metadata, such as “Store File Path”, “Object ID” and “Type”.
                    This allows to look up referred objects in the same Store,
                    as well as to query for the same Element with different
                    Flags  #>

                    $ElementParam.Add( 'Element', $InputObject )
                }
                else
                {
                 <# “Device” is a fallback query path. It only allows to check
                    whether value was specified and warn the user that data
                    cannot be resolved  #>

                    $ElementParam.Add( 'Device', $device )
                }

                $additionalOption = Get-bcdElementAdditionalOption @elementParam

                $value.Add( 'Additional Options'  ,  $additionalOption )
                $value.Add( 'Parent'              ,  $parent           )
                $value.Add( 'Path'                ,  $device.Path      )
            }
            
            5  # Unknown
            {
                $value.Add( 'Data'                ,  $device.Data      )
            }
    
            6  # QualifiedPartition
            {
                $disk      = Get-Disk | Where-Object -FilterScript {
                    $psItem.Guid -eq $device.DiskSignature
                }

                if
                (
                    $disk
                )
                {
                    $partition = Get-Partition -Disk $disk | Where-Object -FilterScript {
                        $psItem.Guid -eq $device.PartitionIdentifier
                    }
                }
                else
                {
                    $message = "Cannot locate disk with Signature $($device.DiskSignature)"
                    Write-Warning -Message $message

                    $partition = $null
                }

                $value.Add( 'Partition'           ,  $partition        )

                if
                (
                    $InputObject
                )
                {
                 <# “Element” is the preferred query method because it provides
                    metadata, such as “Store File Path”, “Object ID” and “Type”.
                    This allows to look up referred objects in the same Store,
                    as well as to query for the same Element with different
                    Flags  #>

                    $elementParam.Add( 'Element', $InputObject )
                }
                else
                {
                 <# “Device” is a fallback query path. It only allows to check
                    whether value was specified and warn the user that data
                    cannot be resolved  #>

                    $elementParam.Add( 'Device', $device )
                }

                $additionalOption = Get-bcdElementAdditionalOption @elementParam

                $value.Add( 'Additional Options'  ,  $additionalOption )
            }

            7  # Locate
            {
              # Not properly implemented yet, looking for real world examples

                $value.Add( 'Path'                ,  $device.Path      )
            }            
            
            8  # LocateEx
            {
              # Not properly implemented yet, looking for real world examples

                $value.Add( 'Path'                ,  $device.Path      )
            }

            Default
            {
                throw "Unknown device type $psItem"
            }
        }

        if
        (
            $Format
        )
        {
            $Property = @()

            $Value.GetEnumerator() | ForEach-Object -Process {

                $Label = $psItem.Key

                $StringBuilder = [System.Text.StringBuilder]::New()

                [System.Void]( $StringBuilder.Append( '$psItem[ '''  ) )
                [System.Void]( $StringBuilder.Append( "$Label"       ) )
                [System.Void]( $StringBuilder.Append( ''' ]'         ) )

                $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create(                            
                    $StringBuilder.ToString()
                )

                $Property += @{
                    Label      = $Label
                    Expression = $ScriptBlock
                }
            }

            return Select-Object -InputObject $value -Property $Property
        }
        else
        {
            return $value
        }
    }

    end
    {}
}