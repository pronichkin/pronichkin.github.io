#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

 <# Assumptions

 1. By default, Boot (aka “Windows”) partition IS created and Data partition IS
    NOT. If you want BOTH of them, you HAVE TO:
     a. explicitly set numeric value (size) for the Boot partition, and
     b. set either a numeric value (size) for Data partition, or specify $True.
        In the latter case, the partition will take the rest of the disk. (And
        can be further shrinked to make room for Recovery partition.)

 2. If you set explicit numeric value (size) for ANY partition(s), it is up to
    you to ensure they will fit on the disk. There's no upfront validation for
    partition sizes.

    For explanation of individual behavior and defaults for each of the supported
    partitions, see comment block between respective partition creation.
  #>

Function
Initialize-DiskEx
{
   #region Data

        [cmdletbinding()]

        Param(
            [parameter(
                Mandatory         = $True,
                ValueFromPipeline = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.Management.Infrastructure.CimInstance]
            $Disk
        ,        
            [Parameter()]
            [ValidateSet(
                "MBR",
                "GPT"
            )]
            [System.String]
            $PartitionStyle = "GPT"
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Mount
        ,
          # Partition options. We use “2” to track the default value (no user input)

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.uInt64]
            $System   = 2
        ,
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.uInt64]
            $Reserved = 2
        ,
            [Parameter()]
            [Alias("Windows")]
            [ValidateNotNullOrEmpty()]
            [System.uInt64]
            $Boot     = 2
        ,
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.uInt64]
            $Data     = 2
        ,
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.uInt64]
            $Recovery = 2
        )

   #endregion Data

   #region Initialize disk

    $InitializeDiskParam = @{

        InputObject = $Disk
        PassThru    = $True
    }                    

    Write-Verbose -Message "Disk $($Disk.Number), `“$($Disk.FriendlyName)`”"

    Switch ( $PartitionStyle )
    {
        "MBR"
        {
            Write-Verbose -Message "Initializing with MBR"
            Write-Verbose -Message "(This is typical for legacy BIOS-based machines and Generation 1 virtual machines)"

            $InitializeDiskParam.Add( "PartitionStyle", "MBR" )
        }

        "GPT"
        {
            Write-Verbose -Message "Initializing with GPT"
            Write-Verbose -Message "(This is typical for modern UEFI-based machines and Generation 2 virtual machines)"
                            
            $InitializeDiskParam.Add( "PartitionStyle", "GPT" )
        }
    }

    $Disk = Initialize-Disk @InitializeDiskParam

  # Remove the default MSR partition.

    If ( $PartitionStyle -eq "GPT" )
    {
                      
        # By default, a 32 MB Reserved (MSR) partition was created.
        # We do not necessarily need it. (And if we do, it should
        # follow the System partition and be of requested size.)

        $ReservedPartition = Get-Partition -Disk $Disk |
            Where-Object -FilterScript {
                $psItem.GptType -eq "{e3c9e316-0b5c-4db8-817d-f92df00215ae}"
            }
                        
        $RemovePartitionParam = @{

            InputObject = $ReservedPartition
            Confirm     = $False
            PassThru    = $True
        }
                        
        Write-Debug -Message "    Removing the default Reserved (MSR) partition"
                                                
        $ReservedPartition = Remove-Partition @RemovePartitionParam
    }

   #endregion Initialize disk

   #region Create partitions and format volumes

    $Summary = @{}

  # System partition (ESP)

     <# Default behavior (no explicit input from user, indicated by value “2”):
          * on MBR disks—do not create the System partition;
          * on GPT disks—create the System partition.
    
        Default size is 260 MB, unless a numeric value was provided.

       “For Advanced Format 4K Native drives (4-KB-per-sector) drives, the
        minimum size is 260 MB, due to a limitation of the FAT32 file format.
        The minimum partition size of FAT32 drives is calculated as sector size
        (4KB) × 65527 = 256 MB.”
        (https://msdn.microsoft.com/library/windows/hardware/dn898510)

        User can explicitly disable creation of System partition on GPT disk by
        setting its Value (aka size) to $False (0). Or force creation for System
        partition on MBR disk by setting it to $True or any numeric value (size).
      #>

    If (
        ( $PartitionStyle -eq "MBR" -and $System -notin @( 0, 2 ) ) -or
        ( $PartitionStyle -eq "GPT" -and $System )
    )
    {
       #region Create partition

            Write-Verbose -Message "Processing System partition"

            If ( $System -in @( 1, 2 ) )
            {
                $System = 260mb
            }

            Write-Debug -Message "    Partition size will be $System bytes"

            $NewPartitionParam = @{
                            
                InputObject       = $Disk
                Size              = $System
                AssignDriveLetter = $False
            }

            Switch ( $PartitionStyle )
            {
                "MBR"
                {
                    $NewPartitionParam.Add( "MbrType", "FAT32" )
                    $NewPartitionParam.Add( "IsActive", $True )
                }

                "GPT"
                {
                    $NewPartitionParam.Add( "GptType", "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" )
                }
            }

            Write-Debug -Message "    Creating partition"

            $SystemPartition = New-Partition @NewPartitionParam

       #endregion Create partition

       #region Format volume

            $FormatVolumeParam = @{
                            
                Partition          = $SystemPartition
                FileSystem         = "FAT32"
                NewFileSystemLabel = "System"
                Confirm            = $False
                Force              = $True
            }

            Write-Debug -Message "    Formatting volume"

            $SystemVolume = Format-Volume @FormatVolumeParam

            If ( $Mount )
            {
              # Add partition access path (mount to NTFS directory).

                $SystemPath   = Join-Path -Path $Mount      -ChildPath "System"
                $SystemFolder = New-Item  -Path $SystemPath -ItemType  "Directory"

                $AddPartitionAccessPathParam = @{
                                
                    InputObject = $SystemPartition
                    AccessPath  = $SystemPath
                    PassThru    = $True
                }
                            
                Write-Debug -Message "    Mounting partiiton to `“$SystemPath`”"

                $SystemPartition = Add-PartitionAccessPath @AddPartitionAccessPathParam

              # Refresh Partiton object so that it reflect newly added path
              # (This does not seem to help for Volumes, unfortunately.)

                $SystemPartition = Get-Partition -Volume $SystemVolume
            }
            Else
            {
                $SystemPath = $SystemVolume.Path
            }

            $Summary.Add( "System", $SystemPartition )

        #endregion Format volume
    }
    Else
    {
        Write-Verbose -Message "System partition (ESP) is not created"
    }

  # Reserved (MSR) partition
    
     <# Default behavior (no explicit input from user, indicated by value “2”):
          * on MBR disks—do not create the System partition;
          * on GPT disks—create the System partition.

        Default size is 16 MB, unless a numeric value was provided.
    
       “Beginning in Windows 10, the size of the MSR is 16 MB.”
        (https://msdn.microsoft.com/library/windows/hardware/dn898510)

        User can explicitly disable creation of Reserved partition on GPT disk by
        setting its Value (aka size) to $False (0). However, it is not possible
        to force creation of Reserved partition on MBR disk.
      #>

    If ( $PartitionStyle -eq "GPT" -and $Reserved )
    {
       #region Create partition

            Write-Verbose -Message "Processing Reserved partition (MSR)"

            If ( $Reserved -in @( 1, 2 ) )
            {
                $Reserved = 16mb
            }

            Write-Debug -Message "    Partition size will be $Reserved bytes"

            $NewPartitionParam = @{
                            
                InputObject       = $Disk
                GptType           = "{e3c9e316-0b5c-4db8-817d-f92df00215ae}"
                Size              = $Reserved
                AssignDriveLetter = $False                                
            }

            Write-Debug -Message "    Creating partition"

            $ReservedPartition = New-Partition @NewPartitionParam

        #endregion Create partition

      # Note: there's no need to format MSR partition or assign a path to it.
    }
    Else
    {
        Write-Verbose -Message "Reserved (MSR) partition is not created"
    }

  # Boot (Windows) partition

     <# Default behavior (no explicit input from user, indicated by value “2”):
          * on MBR and GPT disks—create Boot partition.
    
        Default size is the rest of the disk, unless a numeric value was
        provided.

        User can explicitly disable creation of Boot partition by setting its
        Value (aka size) to $False (0).
      #>

    If ( $Boot )
    {
       #region Create partition

            Write-Verbose -Message "Processing Boot (Windows) partition"

            $NewPartitionParam = @{
                            
                InputObject       = $Disk
                AssignDriveLetter = $False
            }

            If ( $Boot -in @( 1, 2 ) )
            {
                $NewPartitionParam.Add( "UseMaximumSize", $True )

                Write-Debug -Message "    Partition will take the rest of the disk"
            }
            Else
            {
                $NewPartitionParam.Add( "Size", $Boot )

                Write-Debug -Message "    Partition size will be $Boot bytes"
            }

            Switch ( $PartitionStyle )
            {
                "MBR"
                {
                    $NewPartitionParam.Add( "MbrType", "IFS" )

                    If ( $System -in @( 0, 2 ) )
                    {

                        # There was no System partition explicitly
                        # requested, so Boot partition will be active.

                        $NewPartitionParam.Add( "IsActive", $True )
                    }
                }

                "GPT"
                {
                    $NewPartitionParam.Add( "GptType", "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" )
                }
            }

            Write-Debug -Message "    Creating partition"

            $BootPartition = New-Partition @NewPartitionParam

       #endregion Create partition

       #region Format volume

            $FormatVolumeParam = @{
                            
                Partition          = $BootPartition
                FileSystem         = "NTFS"
                NewFileSystemLabel = "Windows"
                Confirm            = $False
                Force              = $True
            }

            Write-Debug -Message "    Formatting volume"

            $BootVolume = Format-Volume @FormatVolumeParam

            If ( $Mount )
            {
              # Add partition access path (mount to NTFS directory).

                $BootPath   = Join-Path -Path $Mount      -ChildPath "Boot"
                $BootFolder = New-Item  -Path $BootPath   -ItemType  "Directory"

                $AddPartitionAccessPathParam = @{
                                
                    InputObject = $BootPartition
                    AccessPath  = $BootPath
                    PassThru    = $True
                }
                            
                Write-Debug -Message "    Mounting partiiton to `“$BootPath`”"

                $BootPartition = Add-PartitionAccessPath @AddPartitionAccessPathParam

              # Refresh Partiton object so that it reflect newly added path
              # (This does not seem to help for Volumes, unfortunately.)

                $BootPartition = Get-Partition -Volume $BootVolume
            }

            $Summary.Add( "Boot", $BootPartition )

        #endregion Format volume
    }
    Else
    {
        Write-Verbose -Message "Boot (Windows) partition is not created"
    }

  # Boot Data partition

     <# Default behavior (no explicit input from user, indicated by value “2”):
          * on MBR and GPT disks—do not create Data partition.
    
        Default size is the rest of the disk, unless a numeric value was
        provided.

        User can explicitly force creation of Data partition by setting its
        Value (aka size) to $True (1) or providing custom size.
      #>

    If ( $Data -notin @( 0, 2 ) )
    {
       #region Create partition

            Write-Verbose -Message "Processing Data partition"

            $NewPartitionParam = @{
                            
                InputObject       = $Disk
                AssignDriveLetter = $False
            }

            If ( $Data -eq 1 )
            {
                $NewPartitionParam.Add( "UseMaximumSize", $True )

                Write-Debug -Message "    Partition will take the rest of the disk"
            }
            Else
            {
                $NewPartitionParam.Add( "Size", $Data )

                Write-Debug -Message "    Partition size will be $Data bytes"
            }

            Switch ( $PartitionStyle )
            {
                "MBR"
                {
                    $NewPartitionParam.Add( "MbrType", "IFS" )
                }

                "GPT"
                {
                    $NewPartitionParam.Add( "GptType", "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" )
                }
            }

            Write-Debug -Message "    Creating partition"

            $DataPartition = New-Partition @NewPartitionParam

       #endregion Create partition

       #region Format volume

            $FormatVolumeParam = @{
                            
                Partition          = $DataPartition
                FileSystem         = "NTFS"
                NewFileSystemLabel = "Data"
                Confirm            = $False
                Force              = $True
            }

            Write-Debug -Message "    Formatting volume"

            $DataVolume = Format-Volume @FormatVolumeParam

            If ( $Mount )
            {
              # Add partition access path (mount to NTFS directory).

                $DataPath   = Join-Path -Path $Mount      -ChildPath "Data"
                $DataFolder = New-Item  -Path $DataPath   -ItemType  "Directory"

                $AddPartitionAccessPathParam = @{
                                
                    InputObject = $DataPartition
                    AccessPath  = $DataPath
                    PassThru    = $True
                }
                            
                Write-Debug -Message "    Mounting partiiton to `“$DataPath`”"

                $DataPartition = Add-PartitionAccessPath @AddPartitionAccessPathParam

              # Refresh Partiton object so that it reflect newly added path
              # (This does not seem to help for Volumes, unfortunately.)

                $DataPartition = Get-Partition -Volume $DataVolume
            }

            $Summary.Add( "Data", $DataPartition )

        #endregion Format volume
    }
    Else
    {
        Write-Verbose -Message "Data partition is not created"
    }

  # Recovery partition

     <# Default behavior (no explicit input from user, indicated by value “2”):
          * on MBR and GPT disks—do not create Recovery partition.
    
        Default size is 300 MB at the end of the disk, unless a numeric value
        was provided.

       “This partition must be at least 300 MB.”
        (https://msdn.microsoft.com/library/windows/hardware/dn898510)

        User can explicitly force creation of Recovery partition by setting its
        Value (aka size) to $True (1) or providing custom size.
      #>

    If ( $Recovery -notin @( 0, 2 ) )
    {
        #region Create partition

            Write-Verbose -Message "Processing Recovery partition"

            If ( $Recovery -eq 1 )
            {
                $Recovery = 300mb
            }

            Write-Debug -Message "    Partition size will be $Recovery bytes"

            If ( $Data -eq 1 )
            {
              # We have used default, i.e. maximum size for the
              # Data partition. So now we need to shrink
              # it and free some space for the Recovery partition.

                $Data = $DataPartition.Size  # Current size
                $Data = $Data - $Recovery    # Desired size

                $ResizePartitionParam = @{
                                    
                    InputObject = $DataPartition
                    Size        = $Data
                    PassThru    = $True
                }

                Write-Debug -Message "    Resizing Data Partition to $Data bytes"

                $DataPartition = Resize-Partition @ResizePartitionParam
            }
            ElseIF ( $Boot -in @( 1, 2 ) )
            {
              # We have used default, i.e. maximum size for the
              # Boot (Window) partition. So now we need to shrink
              # it and free some space for the Recovery partition.

                $Boot = $BootPartition.Size  # Current size
                $Boot = $Boot - $Recovery    # Desired size

                $ResizePartitionParam = @{
                                    
                    InputObject = $BootPartition
                    Size        = $Boot
                    PassThru    = $True
                }

                Write-Debug -Message "    Resizing Boot (Windows) Partition to $Boot bytes"

                $BootPartition = Resize-Partition @ResizePartitionParam
            }

            $NewPartitionParam = @{
                            
                InputObject       = $Disk
                Size              = $Recovery
                AssignDriveLetter = $False
            }

            Switch ( $PartitionStyle )
            {
                "MBR"
                {
                    $NewPartitionParam.Add( "MbrType", "IFS" )
                }

                "GPT"
                {
                    $NewPartitionParam.Add( "GptType", "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" )
                }
            }

            Write-Debug -Message "    Creating partition"

            $RecoveryPartition = New-Partition @NewPartitionParam

            $SetPartitionParam = @{ InputObject = $RecoveryPartition }

            Switch ( $PartitionStyle )
            {
                "MBR"
                {
                  # 39 is Dec for 0x27, i.e. Recovery/utility partition.

                    $SetPartitionParam.Add( "MbrType", "39" )

                    Write-Debug -Message "    Setting partition properties"

                  # Set-Partition does not output any objects and does
                  # not have a “-PassThru” parameter.

                    Set-Partition @SetPartitionParam
                }

                "GPT"
                {
                  # We need a command to set GPT attributes to
                  # 0x0000000000000001
                  # (GPT_ATTRIBUTE_PLATFORM_REQUIRED), but
                  # currently there's none.
                }
            }

        #endregion Create partition

        #region Format volume

            $FormatVolumeParam = @{
                            
                Partition          = $RecoveryPartition
                FileSystem         = "NTFS"
                NewFileSystemLabel = "Recovery"
                Confirm            = $False
                Force              = $True
            }

            Write-Debug -Message "    Formatting volume"

            $RecoveryVolume = Format-Volume @FormatVolumeParam

            If ( $Mount )
            {
              # Add partition access path (mount to NTFS directory).

                $RecoveryPath   = Join-Path -Path $Mount        -ChildPath "Recovery"
                $RecoveryFolder = New-Item  -Path $RecoveryPath -ItemType  "Directory"

                $AddPartitionAccessPathParam = @{
                                
                    InputObject = $RecoveryPartition
                    AccessPath  = $RecoveryPath
                    PassThru    = $True
                }
                            
                Write-Debug -Message "    Mounting partiiton to `“$RecoveryPath`”"

                $RecoveryPartition = Add-PartitionAccessPath @AddPartitionAccessPathParam

              # Refresh Partiton object so that it reflect newly added path
              # (This does not seem to help for Volumes, unfortunately.)

                $RecoveryPartition = Get-Partition -Volume $RecoveryVolume
            }

            $Summary.Add( "Recovery", $RecoveryPartition )

        #endregion Format volume
    }
    Else
    {
        Write-Verbose -Message "Recovery partition is not created"
    }

   #endregion Create partitions and format volumes

    Return $Summary
}