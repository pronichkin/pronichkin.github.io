$eOSDevice          = Invoke-CimMethod -InputObject $BootLoader -MethodName 'GetElement' -Arguments @{ 'Type' = 0x21000001 }
$eApplicationDevice = Invoke-CimMethod -InputObject $BootLoader -MethodName 'GetElement' -Arguments @{ 'Type' = 0x11000001 }

$eOSDeviceF          = Invoke-CimMethod -InputObject $eOSDevice.Element.Device -MethodName 'GetElementWithFlags' -Arguments @{ 'Type' = 0x21000001; 'Flags' = 1 }
$eApplicationDeviceF = Invoke-CimMethod -InputObject $BootLoader -MethodName 'GetElementWithFlags' -Arguments @{ 'Type' = 0x11000001; 'Flags' = 1 }



$SetQualifiedPartitionDeviceElement = Invoke-CimMethod -InputObject $BootLoader -MethodName 'SetQualifiedPartitionDeviceElement' -Arguments @{

    'Type'                = 0x11000043   # BcdLibraryDevice_BsdLogDevice
    'PartitionStyle'      = 1            # GPT
    'DiskSignature'       = $Disk.Guid
    'PartitionIdentifier' = $BootPartition.Guid
}

$DeleteElement = Invoke-CimMethod -InputObject $BootLoader -MethodName 'DeleteElement' -Arguments @{

    'Type'                = 0x11000043   # BcdLibraryDevice_BsdLogDevice
}


$ElementApplicationDeviceOld = Invoke-CimMethod -InputObject $BootLoader -MethodName 'GetElement' -Arguments @{ 'Type' = 0x11000001 }

$SetQualifiedPartitionDeviceElement = Invoke-CimMethod -InputObject $BootLoader -MethodName 'SetQualifiedPartitionDeviceElement' -Arguments @{

    'Type'                = 0x11000001   # BcdLibraryDevice_ApplicationDevice
    'PartitionStyle'      = 1            # GPT
    'DiskSignature'       = $Disk.Guid
    'PartitionIdentifier' = $BootPartition.Guid
}



$ElementApplicationDeviceTemp = Invoke-CimMethod -InputObject $BootLoader -MethodName 'GetElement' -Arguments @{ 'Type' = 0x11000001 }

$SetFileDeviceElement = Invoke-CimMethod -InputObject $BootLoader -MethodName 'SetFileDeviceElement' -Arguments @{

    'Type'                    = 0x11000001   # BcdLibraryDevice_ApplicationDevice
    'DeviceType'              = 4            # Ramdisk
    'AdditionalOptions'       = $ElementApplicationDeviceOld.Element.Device.AdditionalOptions
    'Path'                    = $ElementApplicationDeviceOld.Element.Device.Path
    'ParentDeviceType'        = 2            # PartitionDevice
    'ParentAdditionalOptions' = [System.String]::Empty
    'ParentPath'              = $ElementApplicationDeviceTemp.Element.Device.Path
}

$SetFileDeviceElement = Invoke-CimMethod -InputObject $BootLoader -MethodName 'SetFileDeviceElement' -Arguments @{

    'Type'                    = 0x21000001   # BcdOSLoaderDevice_OSDevice
    'DeviceType'              = 4            # Ramdisk
    'AdditionalOptions'       = $ElementApplicationDeviceOld.Element.Device.AdditionalOptions
    'Path'                    = $ElementApplicationDeviceOld.Element.Device.Path
    'ParentDeviceType'        = 2            # PartitionDevice
    'ParentAdditionalOptions' = [System.String]::Empty
    'ParentPath'              = $ElementApplicationDeviceTemp.Element.Device.Path
}