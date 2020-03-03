 <# We will create multiple partitons to overcome filesystem constrains.

  * System partition MUST be FAT32 in order to boot on a UEFI machine. However,
    it does not have to host large files.

  * Boot partitoin needs to host large files (4GB+). However, it does not need
    to be seen from UEFI, hence it can be NTFS (or exFAT)  #>

#region Input

  # Friendly name (as seen by “Get-Disk”) of the USB drive

  # $FriendlyName = 'Kingston DataTraveler 3.0'
    $FriendlyName = 'JetFlash Transcend 16GB'

  # Source ISO

    $SourcePath   = 'D:\Image\14393.0.180202-0906.RS1_REFRESH_SERVER_OEMRET_X64FRE_EN-US.ISO'

  # You can customize the volume labels

    $BootLabel   = 'Boot'
    $SystemLabel = 'System'

  # The list of files or directories to be copied to respective partitions

    $Copy = @{

        'System' = @(

            'boot'
            'efi'
            'bootmgr'
            'bootmgr.efi'
        )

        'Boot' = @(

            'sources'
            'support'
            'autorun.inf'
            'setup.exe'
        )
    }

    $SystemType   = [System.Guid]::Parse( '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' )
    $BasicType    = [System.Guid]::Parse( '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' )
    $ReservedType = [System.Guid]::Parse( '{e3c9e316-0b5c-4db8-817d-f92df00215ae}' )

#endregion Input

#region Validate Disk

    Import-Module -Name 'Storage' -Verbose:$False
    
    $Disk = Get-Disk -FriendlyName $FriendlyName

    Switch
    (
        @( $Disk ).Count
    )
    {
        0
        {
            $Message = 'The disk is not found'
            Throw $Message
        }

        1
        {
            $Message = 'Disk found'
            Write-Verbose -Message $Message
        }

        Default
        {
            $Message = 'More than one disk were found'
            Throw $Message
        }
    }

#endregion Validate Disk

#region Mount Disk Image (ISO)

    $DiskImage = Get-DiskImage -ImagePath $SourcePath

    If
    (
        $DiskImage.Attached
    )
    {
        $Message = 'Disk image is already attached'
        Write-Verbose -Message $Message
    }
    Else
    {
        $DiskImage = Mount-DiskImage -InputObject $DiskImage -NoDriveLetter -PassThru -Access ReadOnly
    }

    $Volume = Get-Volume -DiskImage $DiskImage

  # $SourcePath = 'D:\UFD'

  # $BootPath   = Join-Path -Path $SourcePath -ChildPath $BootLabel
  # $SystemPath = Join-Path -Path $SourcePath -ChildPath $SystemLabel

#endregion Mount Disk Image (ISO)

#region Initialize and partition disk

    $Disk = Clear-Disk -InputObject $Disk -Confirm:$False -RemoveData -PassThru

 <# Unlike fixed disks, you do not actually “Initialize” removable meida
    Running “Initialize-Disk” would fail  #>

    Set-Disk -InputObject $Disk -PartitionStyle GPT

 <# Calculate the size of Boot partition as overall Disk size, minus:
 
    512 MB for System partition (ESP)
     16 MB for Microsoft reserved partition (MSR)
      2 MB for GPT overhead  #>

    $BootSize = $Disk.Size - 530mb

 <# Boot partition should be created first. Windows Server 2016 (RS1) only sees
    the first partition of the removable media. This includes when in Windows PE.
    (I.e. RS1 version of Windows PE.) Boot partition is where the installation 
    files are located, so this is the partition which needs to be visible from 
    Windows PE. Other partitions do not need to be visible.

    Windows Server 2019 (RS5) does not have this limitation. It will see all
    the partitions, even on a removable media  #>

    $BootPartition     = New-Partition -InputObject $Disk -Size $BootSize -GptType "{$($BasicType.Guid)}"   # -AssignDriveLetter
  # $SystemPartition   = New-Partition -InputObject $Disk -UseMaximumSize -GptType "{$($BasicType.Guid)}"     -AssignDriveLetter
  # $SystemPartition   = New-Partition -InputObject $Disk -Size 512mb     -GptType "{$($BasicType.Guid)}"   # -AssignDriveLetter
    $SystemPartition   = New-Partition -InputObject $Disk -Size 512mb     -GptType "{$($SystemType.Guid)}"  # -AssignDriveLetter
    $ReservedPartition = New-Partition -InputObject $Disk -UseMaximumSize -GptType "{$($ReservedType.Guid)}"

    $BootVolume   = Format-Volume -Partition $BootPartition   -FileSystem NTFS  -NewFileSystemLabel $BootLabel
    $SystemVolume = Format-Volume -Partition $SystemPartition -FileSystem FAT32 -NewFileSystemLabel $SystemLabel

  # In case the volume was formatted previously and we start from here

  # $BootVolume   = Get-Volume -FileSystemLabel $BootLabel   | Where-Object -FilterScript { $psItem.DriveType -eq 'Removable' }
  # $SystemVolume = Get-Volume -FileSystemLabel $SystemLabel | Where-Object -FilterScript { $psItem.DriveType -eq 'Removable' }

  # $BootPartition   = Get-Partition -Volume $BootVolume
  # $SystemPartition = Get-Partition -Volume $SystemVolume

#endregion Initialize and partition disk

#region Copy files and directories

 <# Now that we have partition objects, transform the list of files to be copied
    so that it refers to actual partitions rather than placeholder names.
   (We will use these partition objects later to determine paths to copy files.)
  #>

    $CopyPartition = @{

        $SystemPartition = $Copy[ 'System' ]
        $BootPartition   = $Copy[ 'Boot'   ]
    }

 <# Now once we have unified reference with partitions and file names, build 
    an actual list including files to be copied. Why so many interim steps?
    Because the copy operation is non-trivial, so that we rather have it
    coded once and iterate through the entire list at one pass  #>

    $CopyFile = @{}

    $CopyPartition.GetEnumerator() | ForEach-Object -Process {

        $Partition = $psItem.Key

        $psItem.Value | ForEach-Object -Process {

            $Path = Join-Path -Path $Volume.Path -ChildPath $psItem

          # Write-Verbose -Message $Path

            $Item = Get-Item -LiteralPath $Path

            $CopyFile.Add( $Item, $Partition )
        }
    }

 <# Workaround required because PowerShell native “Copy-Item” cannot copy
    directories into a global-rooted (“\\?\Volume{<GUID>}\”) path, e.g. 
    a volume without a drive letter. The error being returned is
   “Path cannot be the empty string or all whitespace.”    
    
    (Interestingly, it has no problem copying files)  #>

    $CopyFile.GetEnumerator() | ForEach-Object -Process {
    
        $Destination = $psItem.Value.AccessPaths[0]

        If
        (
            $psItem.Key.psIsContainer
        )
        {
            $PathDestination = Join-Path -Path $Destination -ChildPath $psItem.Key.Name

            $Directory = [System.IO.Directory]::CreateDirectory( $PathDestination )

            $PathSource = Join-Path -Path $psItem.Key.FullName -ChildPath '*'

            $Message = "Copying `“$PathSource`” to `“$($Directory.FullName)`”"
            Write-Verbose -Message $Message

            Get-ChildItem -Path $PathSource | Copy-Item -Destination $Directory.FullName -Force -Recurse
        }
        Else
        {
            $Message = "Copying `“$($psItem.Key.FullName)`” to `“$Destination`”"
            Write-Verbose -Message $Message

            Copy-Item -LiteralPath $psItem.Key.FullName -Destination $Destination -Force
        }
    }

  # Copy-Item -Path "$SystemPath\*" -Destination $SystemPartition.AccessPaths[0] -Recurse -Container
  # Copy-Item -Path "$BootPath\*"   -Destination $BootPartition.AccessPaths[0]   -Recurse -Container

    $DiskImage = Dismount-DiskImage -InputObject $DiskImage

#endregion Copy files and directories

#region Adjust BCD

 <# There are two copies of BCD, one is used when booting in legacy BIOS mode,
    and the other is for UEFI. We only care about the latter as you do not
    need all the USB multi-partition story to boot on BIOS. It is probably
    possible to modify the script so that the USB drive boots on both
    architectures. However, it would require multiple adjustments and much more
    testing  #>
    
    $PathParam = @{
    
        Path      = $SystemPartition.AccessPaths[0]
        ChildPath = 'efi\microsoft\boot\bcd'
    }
    $bcdPath = Join-Path @PathParam

 <# In BCD, a RAM disk is described as a standard object of type “Boot Loader”
   (0x10200003, similar to any other Windows OS loader.) The “Device”
   (0x11000001 aka “Application Device”) and “OS Device” (0x21000001) elements
    of this object are specified in “Bcd Device File Data” element format. They
    describe the path (and settings) for the RAM disk file (“boot.wim”.)
    
    In particular, the “Parent” section (i.e. value in square braces) of this
    format should point to a partition, using “Bcd Device Data” element
    format. Remaining part (outside of square braces) specifies a path relative
    to this partition. 
    
    By default, the “Parent” has value with Device Type of “1” which stands for
    “Boot Device” That's displayed as “[boot]” in BcdEdit. It means “Device that
    initiated the boot,” or in other words the System partition. This works as
    long as “boot.wim” is located on the same volume (or in other words, when
    Boot and System volumes are the same.) Which is true for CD/DVD (and hence
    for the ISOs.)
    
    We might keep “boot.wim” on the System partition (as it will fit into FAT32
    limitations.) And that would allow to keep BCD intact. Unfortunately, that
    would break Windows setup as it expects to find “install.wim” in the same
    location.

   (One could work around that by manually relaunching Setup.exe from the 
    correct location, using Shift+F10 command prompt. However, that would be
    significantly different experience which is less intuitive than just booting
    from meida and following prompts.)

    Hence, we're moving the entire “Sources” directory into the Boot partition.
   (That would also help updating the USB drive. You only have to copy 
    couple folders in right places, without cherry-picking individual files.)

    And now given that it's a different partition from the System partition,
    we need to update the path to “boot.wim” in the BCD. More specifically, the
   “Parent” value should contain a reference to the Boot partition. (Which is
    now different from System partition.) Typically one would specify it by the
    drive letter, and can easily do so using BcdEdit.
 
    $Drive  = $BootPartition.AccessPaths[0]
    $Device =
        "ramdisk=[$Drive]\sources\boot.wim,{7619dcc8-fafe-11d9-b411-000476eba25f}"

    bcdedit.exe /Store $bcdPath /Set `{Default`}   Device $Device
    bcdedit.exe /Store $bcdPath /Set `{Default`} osDevice $Device

    However, in case a drive letter is not present, this task becomes unexpectedly
    tricky. The above commands would fail as BCD does not support the global
    rooted paths (e.g. “\\?\Volume{d0e64f0c-375a-4395-83d0-153d4374cde4}\”.)
    
    An alternative format is avaliable (and also acceptbed by BcdEdit)
    which is known as “DOS Device name” (e.g. “\Device\HarddiskVolume23”.)
    Unfortunately, there's no straightforward way to figure out this name for a
    given partition in Windows, unless you're willing to do some P/Invoke.

    (I personally tend to avoid P/Invoke at all costs as it's utterly difficult
    from readability and error handling perspectives.)

    Turns out, when specifying a plain partition value (“Bcd Device Partition 
    Data”), i.e. not in case of a parent for “File Device Element” (RAM Disk),
    one could use an alternative format which is called “Bcd Device Qualified
    Partition Data.” (This is just a different way to specify input data.
    Internally it gets stored as standard “Bcd Device Partition Data” element.)
    
    This format is trivial to define because we already know all necessary pieces
    of input. More importantly, after setting it this way, we can query back for
    regular “Bcd Device Partition Data” information, and hence retrieve the “DOS
    Device Name.” (Which we need for the “File Device Element”, i.e. a RAM Disk).
    
    You cannot set “Bcd Device Qualified Partition Data” using BcdEdit, but WMI
    implementation is available (and still more friendly to PowerShell than
    P/Invoke.)

    Hence, we're temporarily setting “Device” (aka “Application Device”) to a
    plain partition value (“Bcd Device Partition Data”) in “Bcd Device Qualified
    Partition Data” format (Device Type of 6).  #>
   
  # “PS BCD module” is available from
  # https://github.com/pronichkin/pronichkin.github.io/tree/master/psbcd
    Import-Module -Name 'psBcd' -Verbose:$False

    $File   = Get-Item -Path $bcdPath

  # Open the BCD store
    $Store  = Get-bcdStore -File $File

  # Obtain the Boot Manager object
    $BootManager        = Get-bcdObject -Store $Store -Type 'Windows_boot_manager'

  # Find out which Boot Loader object is the default
    $BootManagerDefault = Get-bcdObjectElement -Object $BootManager -Type 'DefaultObject'

  # Obtain the Boot Loader object
    $BootLoader         = Get-bcdObject -Store $Store -Id $BootManagerDefault.Id

  # The original value, Device Type 4: Ramdisk
    $ApplicationDeviceOriginal = Get-bcdObjectElement -Object $BootLoader -Type 'ApplicationDevice'

  # Temporary value, Device Type 6: Partition Qualified
    $ElementParam = @{

        Object              = $BootLoader
        Type                = 'ApplicationDevice'
        PartitionStyle      = 'Gpt'
        DiskSignature       = $Disk.Guid
        PartitionIdentifier = $BootPartition.Guid
    }
    $ApplicationDevicePartitionQualified = Set-bcdObjectElementDevicePartitionQualified @ElementParam

  # Same temporary value, but in a format of Device Type 2: Partition
    $ApplicationDevicePartitionTemp = Get-bcdObjectElement -Object $BootLoader -Type 'ApplicationDevice'

  # Finally, set the “Application Device” to target value
    $ElementParam = @{

        Object                  = $BootLoader
        Type                    = 'ApplicationDevice'
        DeviceType              = 'Ramdisk'
        AdditionalOptions       = $ApplicationDeviceOriginal.Device.AdditionalOptions
        Path                    = $ApplicationDeviceOriginal.Device.Path
        ParentDeviceType        = 'Partition'
      # ParentAdditionalOptions =                   # Not needed for a RAM disk
        ParentPath              = $ApplicationDevicePartitionTemp.Device.Path
    }
    $ApplicationDevice = Set-bcdObjectElementDeviceFile @ElementParam

  # Likewise, set the “Application Device” to the same value
    $ElementParam = @{

        Object                  = $BootLoader
        Type                    = 'OSDevice'
        DeviceType              = 'Ramdisk'
        AdditionalOptions       = $ApplicationDeviceOriginal.Device.AdditionalOptions
        Path                    = $ApplicationDeviceOriginal.Device.Path
        ParentDeviceType        = 'Partition'
      # ParentAdditionalOptions =                   # Not needed for a RAM disk
        ParentPath              = $ApplicationDevicePartitionTemp.Device.Path
    }
    $OSDevice = Set-bcdObjectElementDeviceFile @ElementParam

#endregion Adjust BCD

#region Adjust partition type

 <# It would be nice to set proper GPT partition type for the System partition,
    however in this case Windows setup won't be able to locate *destination*
    volume. For whatever reason it will fail after partitioning the target
    drive, before applying the image. “Copying files...” step fails at 0% with 
    error 0xC0000005. Hence we're keeping the System partition typed as “Basic” 
    type  #>

  # Set-Partition -InputObject $SystemPartition -GptType "{$($SystemType.Guid)}"
    Set-Partition -InputObject $SystemPartition -GptType "{$($BasicType.Guid)}"

#endregion Adjust partition type