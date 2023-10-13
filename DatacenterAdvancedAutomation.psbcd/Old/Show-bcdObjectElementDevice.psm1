Using Module '.\ElementType.psm1'
Using Module '.\DeviceType.psm1'

<#
    Formats value of “Device” property for meaningful display
    
    Note

    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdObjectElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Show-bcdObjectElementDevice
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
        $Value = @{
        
            DeviceType = [DeviceType].GetEnumName( $Device.DeviceType )
        }

        Switch
        (
            $Device.DeviceType
        )
        {
            1  # Boot
            {
              # No more properties to populate
            }
    
            2  # Partition
            {   
                If
                (
                    $Element
                )
                {
                  # We can query for the same Element as “Qualified Partition”
                  # to retrieve more information

                    $Object             = Get-bcdObject -Store $Store -Id $Element.ObjectId
                    $ElementQualified   = Get-bcdObjectElement -Object $Object -Type $Element.Type -Flag Qualified
                    $PartitionQualified = Show-bcdObjectElementDevice -Device $ElementQualified.Device

                    $Value.Add( 'Partition', $PartitionQualified.Partition )

                    $AdditionalOption = Show-bcdObjectElementAdditionalOption -Element $Element
                }
                Else
                {
                    $AdditionalOption = Show-bcdObjectElementAdditionalOption -Device $Device                
                }

                $Value.Add( 'Additional Options'  ,  $AdditionalOption )
                $Value.Add( 'Path'                ,  $Device.Path      )
            }

            3  # File
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }

            4  # Ramdisk
            {
                $Parent = Show-bcdObjectElementDevice -Device $Device.Parent
                
                If
                (
                    $Element
                )
                {
                    $AdditionalOption = Show-bcdObjectElementAdditionalOption -Element $Element
                }
                Else
                {
                    $AdditionalOption = Show-bcdObjectElementAdditionalOption -Device $Device
                }

                $Value.Add( 'Additional Options'  ,  $AdditionalOption )
                $Value.Add( 'Parent'              ,  $Parent           )
                $Value.Add( 'Path'                ,  $Device.Path      )
            }
            
            5  # Unknown
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }
    
            6  # QualifiedPartition
            {
                $Disk      = Get-Disk | Where-Object -FilterScript { $psItem.Guid -eq $Device.DiskSignature }
                $Partition = Get-Partition -Disk $Disk | Where-Object -FilterScript { $psItem.Guid -eq $Device.PartitionIdentifier }

                If
                (
                    $Element
                )
                {
                    $AdditionalOption = Show-bcdObjectElementAdditionalOption -Element $Element
                }
                Else
                {
                    $AdditionalOption = Show-bcdObjectElementAdditionalOption -Device $Device
                }

                $Value.Add( 'Additional Options'  ,  $AdditionalOption )
                $Value.Add( 'Partition'           ,  $Partition        )
            }

            7  # Locate
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }            
            
            8  # LocateEx
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }

            Default
            {
                $Message = 'Unknonw device type'
                Write-Warning -Message $Message
            }
        }
    }

    End
    {
        Return $Value
    }
}