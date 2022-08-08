# This is a wrapper for New-Vhd with some extra features, e.g. creating a VHD(x)
# without needing to have Hyper-V role installed. The only option NOT implemented
# is creating a VHD(x) with “-Source”, i.e. copying an existing physical disk.

#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Function
New-DiskImageEx
{
   #region Data

        [CmdletBinding()]

        Param(

            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.FileInfo]
            $ParentPath
        ,
            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $Differencing
        ,
            [Parameter(
                ParameterSetName = "PathOnly",
                Mandatory        = $True
            )]
            [Parameter(
                ParameterSetName = "PathAndName",
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Io.FileInfo]
            $Path
        ,
            [Parameter(
                ParameterSetName = "NameOnly",
                Mandatory        = $True
            )]
            [Parameter(
                ParameterSetName = "PathAndName",
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Io.FileInfo]
            $Name
        ,
            [Parameter()]
            [ValidateSet(
                "Vhd",
                "VhdX",
                "VhdS"
            )]
            [System.String]
            $Format = "VhdX"
        ,
            [Parameter()]
            [ValidateSet(
                "Fixed",
                "Dynamic"
            )]
            [System.String]
            $Type = "Dynamic"
        ,
            [Parameter()]
            [ValidateRange(
                512MB,
                64TB
			)]
            [System.uInt64]
            $Size
        ,
            [Parameter()]
            [ValidateRange(
                0,
                256mb
			)]
            [System.uInt64]
            $BlockSize = $Null
        )

   #endregion Data

   #region Code

       #region Validate Parameters

            If ( $Blocksize -and $Type -eq "Fixed" )
            {
                Write-Warning -Message "Block size option does not apply to Fixed disks. It will be ignored"

                $Blocksize = $Null
            }

       #endregion Validate Parameters

       #region Build final Vhd path

            Switch ($PsCmdlet.ParameterSetName)
            {
                "NameOnly"
                {
                    $Path = ( Get-VmHost ).VirtualHardDiskPath
                    $FileName = $Name + ".Vhdx"
                    $Path = Join-Path -Path $Path -ChildPath $FileName
                }
                "PathAndName"
                {
                    $FileName = $Name + ".Vhdx"
                    $Path = Join-Path -Path $Path -ChildPath $FileName
                }
            }

       #endregion Build final Vhd path

       #region Create Vhd

            If
            (
                $ParentPath
            )
            {
				If
                (
                    $Differencing
                )
                {

				  # Create Differencing Vhd. This currently requires
				  # Hyper-V Role being installed.

					$Module = Import-ModuleEx -Name "Hyper-V"
                    $Vhd    = New-Vhd -Path $Path -ParentPath $ParentPath -Differencing
					$Vhd    = Get-DiskImage -ImagePath $Vhd.Path
                }
                
				Else
                {

				  # Just copy an existing VHD.

                    $Item   = Copy-Item -Path $ParentPath -Destination $Path -PassThru
                    $Vhd    = Get-DiskImage -ImagePath $Path
                }
            }

            Else

          # Create Blank (Empty) Vhd. This does NOT require Hyper-V Role.

            {

			  # Add some Win32 API for P/Invoke
                $WindowsImageType = Join-Path -Path $psScriptRoot -ChildPath "WindowsImageType.cs"

                $ReferencedAssemblies = @(
                    
                    "System.Xml"
                    "System.Linq"
                    "System.Xml.Linq" 
                )

                $AddTypeParam = @{

                    Path                 = $WindowsImageType
                    ReferencedAssemblies = $ReferencedAssemblies
                    PassThru             = $True
                    Verbose              = $False
                }
                $WindowsImageType = Add-Type @AddTypeParam

				$Flag = Switch( $Type )
				{
					"Dynamic"
					{
                        "None"
                    }

					"Fixed"
					{
                        "FullPhysicalAllocation"
					}
				}

                Write-Verbose -Message "Creating Virtual Disk file. Depending on the settings specified, this might take a while"
                
              # Write-Debug -Message "    Disk path:       $Path"
                Write-Debug -Message "    Disk size:       $Size"
                Write-Debug -Message "    Disk format:     $Format"
                Write-Debug -Message "    Disk type:       $Type"
              # Write-Debug -Message "    Disk block size: $BlockSize"

                [WIM2Vhd.VirtualHardDisk]::CreateVirtualDiskEx(
                    $Path,
                    $Null,      # ParentPath
                    $Null,      # SourcePath
                    $Size,
                    $Format,
                    $Flag,
                    $BlockSize,
                    $Null,      # SectorSizeInBytes
                    $Null,      # PhysicalSectorSizeInBytes
                    $Null,      # Overwrite
                    0           # Overlapped (zero means to run synchonously)
                )
				$Vhd = Get-DiskImage -ImagePath $Path
            }

       #endregion Create Vhd

    #endregion Code

    Return $Vhd
}