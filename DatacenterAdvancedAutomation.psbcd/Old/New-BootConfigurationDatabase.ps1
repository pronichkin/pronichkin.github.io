#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Function
New-BootConfigurationDatabase
{
   #region Data

        [CmdletBinding()]

        Param(
        
            [Parameter( Mandatory = $True )]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Boot    # Drive letter or mount point to Boot partition (required)
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $System  # Drive letter or mount point to System partition (optional)
        ,
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.Globalization.CultureInfo]
            $Locale
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.FileInfo]
            $BcdBoot
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Log = ( Get-Item -Path $env:Temp )
        ,
            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $Force
        )

   #endregion Data

   #region Code

    $BcdPath                   = @()
    $BootConfigurationDatabase = @()

  # Generate potential BCD store path(s) and check whether BCD is already there

    If ( $System )
    {
      # Specifies the partition path to create the boot files on.
        $BcdBootArg += "/s $System" 

      # If there is a dedicated System partition, it means that the disk
      # potentially can be used on UEFI-based machines.
      # (E.g. Generation 2 virtual machines under Hyper-V.)

        $Path = Join-Path -Path $System -ChildPath "efi\microsoft\boot\bcd"
        $BcdPath += $Path

        If ( Test-Path -Path $Path )
        {
            Write-Verbose -Message "System partition already has EFI BCD store"
            $BootConfigurationDatabase += Get-Item -Path $Path -Force
        }

      # Depending on the partition style, there might or might not be an option
      # to use this disk on BIOS-based machines.
      # (E.g. Generation 1 virtual machines under Hyper-V.)

        $Partition = Get-Partition | Where-Object -FilterScript { $System -in $PSItem.AccessPaths }
        $Disk = Get-Disk -Partition $Partition
        
        Switch ( $Disk.PartitionStyle )
        {
           "MBR"
            {
              # Specifies the firmware type of the target system partition
                $BcdBootArg += "/f ALL"

                $Path = Join-Path -Path $System -ChildPath "boot\bcd"
                $BcdPath += $Path
                
                If ( Test-Path -Path $Path )
                {
                    Write-Verbose -Message "System partition already has BIOS BCD store"
                    $BootConfigurationDatabase += Get-Item -Path $Path -Force
                }
            }

           "GPT"
            {
              # Specifies the firmware type of the target system partition                
                $BcdBootArg += "/f UEFI"
            }
        }        
    }
    Else
    {
      # If there is no dedicated System partition (in other words, the System
      # partition is the same as Boot partition), it means that the disk
      # can only be used on BIOS-based machines.
      # (E.g. Generation 1 virtual machines under Hyper-V.)

      # Specifies the partition path to create the boot files on.
        $BcdBootArg += "/s $Boot"   
        
      # Specifies the firmware type of the target system partition
        $BcdBootArg += "/f BIOS"

        $Path = Join-Path -Path $Boot -ChildPath "boot\bcd"
        $BcdPath += $Path

        If ( Test-Path -Path $Path )
        {
            Write-Verbose -Message "Boot (Windows) partition already has BIOS BCD store"
            $BootConfigurationDatabase += Get-Item -Path $Path -Force
        }
    }

  # Create the BCD

    If ( $Force -or -not $BootConfigurationDatabase )
    {
        Write-Verbose -Message "Making disk bootable"
        
        $Windows = Join-Path -Path $Boot -ChildPath "Windows"

        $BcdBootArg += @(

            "$Windows",   # Path to the \Windows directory
            "/v"          # Enable verbose logging.
        )

        If ( "$Locale" )
        {
            $BcdBootArg += "/l $Locale.Name"
        }

        $StartProcessExParam = @{
                                
            FilePath     = [System.String]::Empty  # Placeholder
            ArgumentList = $BcdBootArg
            Log          = $Log
        }

        If ( $BcdBoot )
        {
            $StartProcessExParam.FilePath = $BcdBoot.FullName
        }
        Else
        {
            $StartProcessExParam.FilePath = "BcdBoot.exe"
        }

        $Process = Start-ProcessEx @StartProcessExParam

        $BootConfigurationDatabase = Get-Item -Path $BcdPath -Force

        Write-Verbose -Message "The disk is now bootable."
    }

    Return $BootConfigurationDatabase

   #endregion Code
}