Function
Format-bcdDeviceData
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
        [System.Byte[]]
        $InputObject
    )    

    begin
    {
        $inputList = [System.Collections.Generic.List[System.Byte]]::new()
    }

    process
    {
        if
        (
            $InputObject.Length -eq 1
        )
        {
            $inputList.Add( $InputObject[0] )
        }
        else
        {
            $inputList = $InputObject
        }
    }

    end
    {
        $value = @{}

      # apparently this does not always work
        [System.Byte[]]$deviceTypeRaw       = $inputList[0x00..0x07]
        [System.Byte[]]$lengthRaw           = $inputList[0x08..0x0F]
        [System.Byte[]]$deviceDataRaw       = $inputList[0x10..($inputList.Count-0x1)]      
      
     <# Additional options are not part of this structure. They are always provided on a level above it.
        [System.Byte[]]$additionalOptionRaw = $inputList[($inputList.Count-0x10)..($inputList.Count-0x1)]  #>

        $length = [System.BitConverter]::ToUInt32( $lengthRaw, 0)

        if
        (
          # $deviceDataRaw.Length -eq $length
            $inputList.Length     -eq $length
        )
        {
            [BCDE_DEVICE_TYPE]$deviceType = [System.BitConverter]::ToUInt32( $deviceTypeRaw, 0)

            $value.Add(
                'DeviceType', $deviceType
            )

            switch
            (
                $deviceType   
            )
            {
                ([BCDE_DEVICE_TYPE]::BCDE_DEVICE_TYPE_QUALIFIED_PARTITION)
                {
                  # known data ranges inside this structure

                  # [System.Byte[]]$flagRaw               = $[0x00..0x07]

                    [System.Byte[]]$partitionSignatureRaw = $deviceDataRaw[0x08..0x17]
                    [System.Byte[]]$partitionStyleRaw     = $deviceDataRaw[0x18..0x1F]
                    [System.Byte[]]$diskSignatureRaw      = $deviceDataRaw[0x20..0x2F]                
                
                 <# we currently do not know what these values stand for.
                  # best guess is it's some bit mask

                    $flag = $flagRaw | ForEach-Object -Process {
                        [System.Convert]::toString( $psItem, 2 ).padLeft( 8, '0' )
                    }
                
                    $value.Add(
                        'Flag', $flag
                    )  #>

                    $partitionStyle = $partitionStyleRaw | ForEach-Object -Process {
                        [System.Convert]::toString( $psItem, 2 ).padLeft( 8, '0' )
                    }                
                
                    $value.Add(
                        'PartitionStyle', $partitionStyle
                    )

                    $partitionIdentifier = [System.Guid]::new( $partitionSignatureRaw )

                  # Get-Partition | Where-Object -FilterScript { $psItem.Guid -eq "{$($partitionIdentifier.ToString())}" }

                    $value.Add(
                        'PartitionIdentifier', $partitionIdentifier
                    )

                    $diskSignature       = [System.Guid]::new( $diskSignatureRaw )
              
                  # Get-Disk      | Where-Object -FilterScript { $psItem.Guid -eq "{$($diskSignature.ToString())}" }

                    $value.Add(
                        'DiskSignature', $diskSignature
                    )
                }

                default
                {
                    throw "Device type $psItem is not currently handled by Format-bcdDevicePartition"
                }
            }
        }
        else
        {
            throw 'Length calculation failed, unknown format!'
        }

     <# $additionalOption    = [System.Guid]::new( $additionalOptionRaw )

        $value.Add(
            'AdditionalOptions', $additionalOption
        )  #>

        return $value
    }
}