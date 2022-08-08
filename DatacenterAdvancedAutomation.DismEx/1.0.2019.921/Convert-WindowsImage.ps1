#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Function
Convert-WindowsImage
{
    [CmdletBinding(
        PositionalBinding       = $False,
        DefaultParameterSetName = "Input"  # Backward-compatible mode which supports arbitrary Edition string
    )]

    param(

      # Source options

        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            HelpMessage       = "Please specify the source Windows Image, as an ISO or WIM file."
        )]
        [Alias(
            "WIM",
            "SourcePath",
            "Source"
        )]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo]
        $Path
    ,
        [Parameter(
            ParameterSetName = "Client",  # Drop-down list to select Client SKU
            Mandatory        = $True
        )]
        [ValidateSet(
            "Core",
            "Professional",
            "Enterprise",
            "WindowsPE"        
        )]
        [System.String[]]
        $ClientEdition
    ,
        [Parameter(
            ParameterSetName = "Server",  # Drop-down list to select Server SKU and installation option
            Mandatory        = $True
        )]
        [ValidateSet(
            "Standard",
            "Datacenter",
            "Workgroup",  # This will work only for Storage Server media
            "Hyper",      # This is Hyper-V Server
            "Solution",
            "Foundation"
        )]
        [String[]]
        $ServerEdition
    ,
        [Parameter(
            ParameterSetName = "Server",
            Mandatory        = $True
        )]
        [ValidateSet(
            "Full",
            "Core",
            "Nano"        
        )]
        [System.String[]]
        $ServerInstallationOption
    ,
        [Parameter( ParameterSetName="Input" )]
        [Alias( "SKU" )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Edition = 1
    ,
      # Output options

        [Parameter()]
        [Alias(
            "WorkDir",
            "WorkingDirectory",
            "VHDPath",
            "VHD"
        )]
        [ValidateNotNullOrEmpty()]
        [System.Io.FileInfo]
        $Destination = ( Get-Location )
    ,
        [Parameter()]
        [Alias(
            "TempDir",
            "TempDirectory"
        )]
        [ValidateNotNullOrEmpty()]
        [System.Io.DirectoryInfo]
        $Temp = $env:Temp
    ,
      # Vhd properties

        [Parameter()]
        [Alias( "SizeBytes" )]
        [ValidateRange( 512MB, 64TB )]
        [System.uInt64]
        $Size = 25GB
    ,
        [Parameter()]
        [Alias( "VhdFormat" )]
        [ValidateSet(
            "VHD",
            "VHDX"
          # "VHDS", Not implemented yet
        )]
        [System.String]
        $Format
    ,
        [Parameter()]
        [Alias(
            "DiskType",
            "VhdType"
        )]
        [ValidateSet(
            "Dynamic",
            "Fixed"
        )]
        [System.String]
        $Type = "Dynamic"
    ,        
        [Parameter()]
        [Alias(
            "DiskLayout",
            "VhdPartitionStyle"
        )]
        [ValidateSet(
            "MBR",
            "GPT"
        )]
        [System.String]
        $PartitionStyle
    ,
        [Parameter()]
        [Alias( "ApplyEA" )]
        [System.Management.Automation.SwitchParameter]
        $ApplyExtendedAttributes
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
        $Recovery = 2
    ,
      # Non-default paths to external tools

        [Parameter()]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo]
        $BcdBoot
    ,
        [Parameter()]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo]
        $BcdEdit
    ,
        [Parameter()]
        [Alias("DismPath")]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo]
        $Dism
    ,
      # Optional image modification

        [Parameter()]
        [Alias(
            "MergeFolder",
            "MergeFolderPath"
        )]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.DirectoryInfo]
        $Merge
    ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Feature
    ,
        [Parameter()]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileSystemInfo[]]
        $Driver
    ,      
        [Parameter()]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo[]]
        $Package
    ,
      # Can be either path (System.Io.FileInfo) or raw XML (System.Xml.XmlDocument)

        [Parameter()]
        [Alias("UnattendPath")]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $Unattend
    ,
      # This is default behavior, but we allow to disable it.

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $NoExpandOnNativeBoot
    ,
        [Parameter()]
        [Alias( "RemoteDesktopEnable" )]
        [System.Management.Automation.SwitchParameter]
        $RemoteDesktop
    ,
      # Boot loader options         

        [Parameter()]
        [Alias( "EnableDebugger" )]
        [ValidateSet(
            "None",
            "Serial",
            "1394",
            "USB",
            "Local",
            "Network"
        )]
        [System.String]
        $Debugger = "None"
    ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Globalization.CultureInfo]
        $BcdLocale
    ,
      # Behavior modifications

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $CacheSource
    ,
        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Passthru
    )

  # Dynamic Parameters are used for the various types of debugging.

    DynamicParam
    {

      # Set up the dynamic parameters.
      # Dynamic parameters are only available if certain conditions are met, so they'll only show up
      # as valid parameters when those conditions apply.  Here, the conditions are based on the value of
      # the Debugger parameter.  Depending on which of a set of values is the specified argument
      # for Debugger, different parameters will light up, as outlined below.

        $parameterDictionary = New-Object -TypeName "System.Management.Automation.RuntimeDefinedParameterDictionary"

        If (Test-Path -Path "Variable:\Debugger")
        {
            Switch ( $Debugger )
            {
                "Serial"
                {
                   #region ComPort

                    $ComPortAttr                   = New-Object System.Management.Automation.ParameterAttribute
                    $ComPortAttr.ParameterSetName  = "__AllParameterSets"
                    $ComPortAttr.Mandatory         = $false

                    $ComPortValidator              = New-Object System.Management.Automation.ValidateRangeAttribute(
                                                        1,
                                                        10   # Is that a good maximum?
                                                     )

                    $ComPortNotNull                = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $ComPortAttrCollection         = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $ComPortAttrCollection.Add($ComPortAttr)
                    $ComPortAttrCollection.Add($ComPortValidator)
                    $ComPortAttrCollection.Add($ComPortNotNull)

                    $ComPort                       = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                        "ComPort",
                                                        [UInt16],
                                                        $ComPortAttrCollection
                                                     )

                  # By default, use COM1
                    $ComPort.Value                 = 1
                    $parameterDictionary.Add("ComPort", $ComPort)

                   #endregion ComPort

                   #region BaudRate

                    $BaudRateAttr                  = New-Object System.Management.Automation.ParameterAttribute
                    $BaudRateAttr.ParameterSetName = "__AllParameterSets"
                    $BaudRateAttr.Mandatory        = $false

                    $BaudRateValidator             = New-Object System.Management.Automation.ValidateSetAttribute(
                                                        9600, 19200, 38400, 57600, 115200
                                                     )

                    $BaudRateNotNull               = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $BaudRateAttrCollection        = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $BaudRateAttrCollection.Add($BaudRateAttr)
                    $BaudRateAttrCollection.Add($BaudRateValidator)
                    $BaudRateAttrCollection.Add($BaudRateNotNull)

                    $BaudRate                      = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "BaudRate",
                                                         [UInt32],
                                                         $BaudRateAttrCollection
                                                     )

                  # By default, use 115,200.
                    $BaudRate.Value                = 115200
                    $parameterDictionary.Add("BaudRate", $BaudRate)

                   #endregion BaudRate

                    break
                }

                "1394"
                {
                    $ChannelAttr                   = New-Object System.Management.Automation.ParameterAttribute
                    $ChannelAttr.ParameterSetName  = "__AllParameterSets"
                    $ChannelAttr.Mandatory         = $false

                    $ChannelValidator              = New-Object System.Management.Automation.ValidateRangeAttribute(
                                                        0,
                                                        62
                                                     )

                    $ChannelNotNull                = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $ChannelAttrCollection         = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $ChannelAttrCollection.Add($ChannelAttr)
                    $ChannelAttrCollection.Add($ChannelValidator)
                    $ChannelAttrCollection.Add($ChannelNotNull)

                    $Channel                       = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "Channel",
                                                         [UInt16],
                                                         $ChannelAttrCollection
                                                     )

                  # By default, use channel 10
                    $Channel.Value                 = 10
                    $parameterDictionary.Add("Channel", $Channel)

                    break
                }

                "USB"
                {
                    $TargetAttr                    = New-Object System.Management.Automation.ParameterAttribute
                    $TargetAttr.ParameterSetName   = "__AllParameterSets"
                    $TargetAttr.Mandatory          = $false

                    $TargetNotNull                 = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $TargetAttrCollection          = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $TargetAttrCollection.Add($TargetAttr)
                    $TargetAttrCollection.Add($TargetNotNull)

                    $Target                        = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "Target",
                                                         [string],
                                                         $TargetAttrCollection
                                                     )

                  # By default, use target = "debugging"
                    $Target.Value                  = "Debugging"
                    $parameterDictionary.Add("Target", $Target)

                    break
                }

                "Network"
                {
                   #region IP
        
                    $IpAttr                        = New-Object System.Management.Automation.ParameterAttribute
                    $IpAttr.ParameterSetName       = "__AllParameterSets"
                    $IpAttr.Mandatory              = $true

                    $IpValidator                   = New-Object System.Management.Automation.ValidatePatternAttribute(
                                                        "\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
                                                     )
                    $IpNotNull                     = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $IpAttrCollection              = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $IpAttrCollection.Add($IpAttr)
                    $IpAttrCollection.Add($IpValidator)
                    $IpAttrCollection.Add($IpNotNull)

                    $IP                            = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "IPAddress",
                                                         [string],
                                                         $IpAttrCollection
                                                     )

                  # There's no good way to set a default value for this.
                    $parameterDictionary.Add("IPAddress", $IP)

                   #endregion IP

                   #region Port

                    $PortAttr                      = New-Object System.Management.Automation.ParameterAttribute
                    $PortAttr.ParameterSetName     = "__AllParameterSets"
                    $PortAttr.Mandatory            = $false

                    $PortValidator                 = New-Object System.Management.Automation.ValidateRangeAttribute(
                                                        49152,
                                                        50039
                                                     )

                    $PortNotNull                   = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $PortAttrCollection            = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $PortAttrCollection.Add($PortAttr)
                    $PortAttrCollection.Add($PortValidator)
                    $PortAttrCollection.Add($PortNotNull)


                    $Port                          = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "Port",
                                                         [UInt16],
                                                         $PortAttrCollection
                                                     )

                  # By default, use port 50000
                    $Port.Value                    = 50000
                    $parameterDictionary.Add("Port", $Port)

                   #endregion Port

                   #region Key

                    $KeyAttr                       = New-Object System.Management.Automation.ParameterAttribute
                    $KeyAttr.ParameterSetName      = "__AllParameterSets"
                    $KeyAttr.Mandatory             = $true

                    $KeyValidator                  = New-Object System.Management.Automation.ValidatePatternAttribute(
                                                        "\b([A-Z0-9]+).([A-Z0-9]+).([A-Z0-9]+).([A-Z0-9]+)\b"
                                                     )

                    $KeyNotNull                    = New-Object System.Management.Automation.ValidateNotNullOrEmptyAttribute

                    $KeyAttrCollection             = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $KeyAttrCollection.Add($KeyAttr)
                    $KeyAttrCollection.Add($KeyValidator)
                    $KeyAttrCollection.Add($KeyNotNull)

                    $Key                           = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "Key",
                                                         [string],
                                                         $KeyAttrCollection
                                                     )

                  # Don't set a default key.
                    $parameterDictionary.Add("Key", $Key)

                   #endregion Key

                   #region NoDHCP

                    $NoDHCPAttr                    = New-Object System.Management.Automation.ParameterAttribute
                    $NoDHCPAttr.ParameterSetName   = "__AllParameterSets"
                    $NoDHCPAttr.Mandatory          = $false

                    $NoDHCPAttrCollection          = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $NoDHCPAttrCollection.Add($NoDHCPAttr)

                    $NoDHCP                        = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "NoDHCP",
                                                         [switch],
                                                         $NoDHCPAttrCollection
                                                     )

                    $parameterDictionary.Add("NoDHCP", $NoDHCP)

                   #endregion NoDHCP

                   #region NewKey

                    $NewKeyAttr                    = New-Object System.Management.Automation.ParameterAttribute
                    $NewKeyAttr.ParameterSetName   = "__AllParameterSets"
                    $NewKeyAttr.Mandatory          = $false

                    $NewKeyAttrCollection          = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
                    $NewKeyAttrCollection.Add($NewKeyAttr)

                    $NewKey                        = New-Object System.Management.Automation.RuntimeDefinedParameter(
                                                         "NewKey",
                                                         [switch],
                                                         $NewKeyAttrCollection
                                                     )

                  # Don't set a default key.
                    $parameterDictionary.Add("NewKey", $NewKey)

                   #endregion NewKey

                    break
                }

              # There's nothing to do for local debugging.
              # Synthetic debugging is not yet implemented.

                default
                {
                   break
                }
            }
        }

        return $parameterDictionary
    }

    Begin 
    {
       #region Constants and Pseudo-Constants
        
            Import-LocalizedData -BindingVariable "ConvertWindowsImage"

          # Name of the script, obviously.
            $scriptName             = "Convert-WindowsImage"

          # Session key, used for keeping records unique between multiple runs.
            $sessionKey             = [Guid]::NewGuid().ToString()

          # Log folder path.
            $logFolder              = [io.path]::Combine( $Temp, $scriptName, $sessionKey )
            $DismLog                = Join-Path -Path $logFolder -ChildPath "Dism.log"

          # Maximum size for VHD is ~2040GB.
            $vhdMaxSize             = 2040GB

          # Maximum size for VHDX is ~64TB.
            $vhdxMaxSize            = 64TB

          # The lowest supported *image* version; making sure we don't run against Vista/2k8.
            $lowestSupportedVersion = New-Object -TypeName "Version" -ArgumentList "6.1"

          # The highest tested *image* version; making sure we don't run against RS1+
            $highestTestedVersion = New-Object -TypeName "Version" -ArgumentList "10.0.14500.0"

          # The lowest supported *host* build.  Set to Win8 CP.
            $lowestSupportedBuild   = 9200

          # Keeps track on whether the script itself enabled Transcript
          # (vs. it was enabled by user)
            $Transcripting          = $false

       #endregion Constants and Pseudo-Constants

       #region Prepare variables

            Write-Information -MessageData $ConvertWindowsImage.Banner
            Write-Information -MessageData $ConvertWindowsImage.Copyright

            $Module = Import-ModuleEx -Name "Dism"
            $Module = Import-ModuleEx -Name "Storage"

            # Create log folder
            If ( Test-Path -Path $logFolder )
            {
                $Item = Remove-Item -Path $logFolder -Force -Recurse
            }

            $Item = New-Item -Path $logFolder -ItemType "Directory" -Force

            # Try to start transcripting.  If it's already running, we'll get an exception and swallow it.
            Try
            {
                $TranscriptPath = Join-Path -Path $logFolder -ChildPath "Convert-WindowsImageTranscript.txt"
                $Transcript     = Start-Transcript -Path $TranscriptPath -Force -ErrorAction "SilentlyContinue"
                $Transcripting  = $True
            }
            catch
            {
                Write-Warning -Message "Transcription is already running.  No Convert-WindowsImage-specific transcript will be created."
                $Transcripting  = $Talse
            }

            # Check to make sure we're running (at least) on Win8.
            If (-Not ( Test-WindowsVersion ))
            {
                Throw "$scriptName requires Windows 8 Consumer Preview or higher.  Please use WIM2VHD.WSF (http://code.msdn.microsoft.com/wim2vhd) if you need to create VHDs from Windows 7."
            }
        
            $vhd = @()

       #endregion Prepare variables

       #region Build EditionID and InstallationType

            Switch ( $psCmdlet.ParameterSetName )
            {
                "Client"
                {
                    $Family = "Client"

                    If ( $ClientEdition -eq "WindowsPE" )
                    {
                        $InstallationType = "WindowsPE"
                        $Edition          = 1                        
                    }
                    Else
                    {
                        $InstallationType = "Client"
                        $Edition          = $ClientEdition
                    }
                }

                "Server"
                {
                    $Family = "Server"

                    Switch ( $ServerInstallationOption )
                    {
                        "Full"
                        {
                            $InstallationType = "Server"
                            $Edition          = $ServerEdition
                        }

                        "Core"
                        {
                            $InstallationType = "Server Core"
                            $Edition          = $ServerEdition
                        }

                        "Nano"
                        {
                            $InstallationType = "Nano Server"
                            $Edition          = $ServerEdition + "Nano"
                        }
                    }
                }
            }

       #endregion Build EditionID and InstallationType

       #region Destination name validation

            If ( $Destination.Extension )

          # Destination was specified as a file name or Fully qualified path.

            {
                If ( $Format -And $Format -Ne $Destination.Extension.TrimStart( "." ) )
                {
                    Write-Warning -Message "You specified both fully qualified Destination, as file path, and Image Format"
                    Throw "In this case, Destination extension should match Format"
                }
                Else
                {
                    $Format = $Destination.Extension.TrimStart( "." )
                }

              # We'll have to rename the Disk Image as requested at the end of the script.

                $NameFinal   = Split-Path -Path $Destination -Leaf
                $Destination = Split-Path -Path $Destination -Parent
                    
                Write-Debug -Message "    Final name of the Image will be $NameFinal"

                If ( $Edition -is [System.Array] )
                {
                    Write-Warning -Message "Multiple Editions were specified with a Destination file name."
                    Write-Warning -Message "Only the first Edition will be processed with the File name specified."
                    Write-Warning -Message "Subsequent Editions will be processed with auto-generated File names."
                }
            }

            Else
            {
                Write-Debug -Message "    $( $ConvertWindowsImage.UseAutoName )"
            }

       #endregion Destination name validation

       #region Format selection
                    
            If ( -Not $Format -And $PartitionStyle )
            {
                Switch ( $PartitionStyle )
                {
                    "MBR"
                    {
                        $Format = "VHD"
                    }
                            
                    "GPT"
                    {
                        $Format = "VHDX"
                    }
                }
            }
            ElseIf ( $Format )
            {
                Switch ( $Format )
                {
                    "VHD"
                    {
                        $PartitionStyle = "MBR"
                    }
                            
                    "VHDX"
                    {
                        $PartitionStyle = "GPT"
                    }
                }
            }
            Else
            {
                Throw "Please specify a least any of the following: Partition Style, Image Format or Fully qualified destination with file extension!"
            }

            # Since we use the VhdFormat in output, make it uppercase.
            # We'll make it lowercase again when we use it as a file extension.
            $Format = $Format.ToUpper()

            If ( $Type -eq "Dynamic" )
            {

                # Choose smallest supported block size for dynamic VHD(X)
                # This does not apply to Fixed disks.
                $BlockSize = 1MB

                # There's a difference between the maximum sizes and smallest
                # blocks for VHDs and VHDXs.  Make sure we follow those.
                If ("VHD" -ilike $Format)
                {
                    If ($Size -gt $vhdMaxSize)
                    {
                        Write-Warning -Message "For the VHD file format, the maximum file size is ~2040GB.  We're automatically setting the size to 2040GB for you."
                        $Size = 2040GB
                    }
                    $BlockSize = 512KB
                }
            }
            Else
            {
                $BlockSize = $Null
            }

       #endregion Format selection

       #region Destination path validation

            # At this point, Destination will always be a Directory, not a file.

            If ( -not ( Test-Path -Path $Destination ) )
            {
                $Item = New-Item -Path $Destination -ItemType "Directory"
            }

            If ( Test-NetworkLocation -Path $Destination )
            {
                Write-Debug -Message "    Destination folder `“$Destination`” is a network location"

                $DestinationFinal = $Destination
                $Destination      = $logFolder
            }                

            # We always create Disk Image using temporary fail-safe name.

            $Name = [System.String]( $sessionKey + "." + $Format.ToLower() )

            Write-Debug -Message "    $Format will be created at: `“$Destination`”"
            Write-Debug -Message "    Temporary $Format name is:  `“$Name`”"

       #endregion Destination path validation

       #region Mount Source disk image

          # Check to see if the WIM is local, or on a network location.  If the latter, copy it locally.

            If ( Test-NetworkLocation -Path $Path )
            {
                $SourceImageName = Split-Path -Path $Path -Leaf

                Write-Verbose -Message "Copying Windows Image `“$SourceImageName`” to temp folder"

                $Item = Copy-ItemEx -Path $Path -Destination $Temp -PassThru
                $Path = Join-Path   -Path $Temp -ChildPath $SourceImageName
                $TempSource = $Path
            }

          # If we're using an ISO, mount it and get the path to the WIM file.

            If ( ( [System.Io.FileInfo]$Path ).Extension -ilike ".ISO" )
            {
                $SourceImageName = Split-Path -Path $Path -Leaf

              # If the ISO isn't local, copy it down so we don't have to
              # worry about resource contention or about network latency.

                If ( Test-NetworkLocation -Path $Path )
                {
                    Write-Verbose -Message "Copying Source disk image `“$SourceImageName`” to temp folder"

                    $Item = Copy-ItemEx -Path $Path -Destination $Temp -PassThru

                    $Path = Join-Path -Path $Temp -ChildPath $SourceImageName

                    $TempSource = $Path
                }

                Write-Verbose -Message "Opening ISO `“$SourceImageName`”"
                $SourceImage = Mount-DiskImage -ImagePath $Path -StorageType "ISO" -PassThru
                $SourceImage = Get-DiskImage   -ImagePath $Path
                $driveLetter = ( Get-Volume -DiskImage $SourceImage ).DriveLetter
                
                $Path   = $driveLetter + ":"
                $Source = Join-Path -Path $Path -ChildPath "sources\sxs"
            }

       #endregion Mount Source disk image

       #region Obtain source Windows image(s)

          # Check to see if there's a WIM file we can muck about with.

          # $WindowsImageAll = Get-WindowsImageEx -Path $Path

            Try
            {
                $WindowsImageAll = Get-WindowsImageEx -Path $Path
            }
            Catch
            {
                Throw "The specified ISO does not appear to be valid Windows installation media."
            }

        Trap
        {
            Write-Verbose -Message ( [system.string]::Empty )
            Write-Error   -Message $psItem
            Write-Verbose -Message "Log folder is `“$logFolder`”"
            Write-Verbose -Message ( [system.string]::Empty )

           #region Emergency clean-up (in case of preliminary exit)

              # If we still have the source image open, close it.

                If (
                    ( Test-Path -Path "Variable:\SourceImage" ) -And
                    $SourceImage -ne $Null
                )
                {
                    Write-Warning -Message "Cleauning up... Source disk image"

                    $SourceImage = Dismount-DiskImage -InputObject $SourceImage -PassThru
                }

              # If we still have a registry hive mounted, dismount it.

                If (
                    ( Test-Path -Path "Variable:\Hive" ) -And
                    $Hive -ne $Null
                )
                {
                    Write-Warning -Message "Cleauning up... Registry hive"

                    Dismount-RegistryHive -HiveMountPoint $mountedHive
                }

              # If destination image is mounted, unmount it

                If (
                    ( Test-Path -Path "Variable:\DestinationImage" ) -And
                    $DestinationImage -ne $Null
                )
                {
                    Write-Warning -Message "Cleauning up... Destination disk image"

                    $DestinationImage = Dismount-DiskImage -InputObject $DestinationImage -PassThru
                }

           #endregion Clean up mounted items in case of preliminary exit.
        }
        


        #endregion Obtain source Windows image(s)
    }

    Process
    {
        $Edition | ForEach-Object -Process {

           #region Source Windows image selection

                $Edition   = $psItem

              # WIM may have multiple images.  Filter on Edition (can be index or name) and try to find a unique image

                Write-Verbose -Message ( [system.string]::Empty )
                Write-Verbose -Message "Looking for the requested Windows image in the source image"

                If ( $InstallationType )

              # We have used one of the new parameter sets which allow to select Edition and Installation Option
                {
                    $WindowsImage = $WindowsImageAll | Where-Object -FilterScript {

                        $psItem.InstallationType -eq $InstallationType -and
                        $psItem.EditionId        -ilike "*$Edition"
                    }
                }
                
                Else

              # Legacy Image match options
                {
                    $ImageIndex = 0;

                  # This is a nice way to check whether Edition was specified as a digit.
                    If ( [Int32]::TryParse( $Edition, [ref]$ImageIndex ) )

                  # Fetch image by Edition Index
                    {
                        $ImagePath = Join-Path -Path $Path -ChildPath "sources\install.wim"
                    
                        $WindowsImage = $WindowsImageAll | Where-Object -FilterScript {
                        
                            $psItem.ImagePath  -eq $ImagePath -and
                            $psItem.ImageIndex -eq $ImageIndex
                        }
                    }

                    Else

                  # Select based on loose Image Name match
                    {
                        $WindowsImage = $WindowsImageAll | Where-Object -FilterScript {

                            $psItem.ImageName -ilike "*$Edition"
                        }
                    }

                  # Build the missing properties

                    $InstallationType = $WindowsImage.InstallationType

                    Switch ( $WindowsImage.ProductType ) {

                        "WinNT"    { $Family = "Client" }
                        "ServerNT" { $Family = "Server" }
                    }
                }

           #endregion Source Windows image selection

           #region Source Windows image validation

                If ( $WindowsImage -is [System.Array] )

              # More than one image found.
                {

                    $ImageCount = $( $WindowsImage.Count )

                    Write-Verbose -Message "WIM file has the following $ImageCount images that match filter *$Edition"
                    $WindowsImage
                    Write-Error -Message "You must specify an Edition name or index, since the WIM has more than one image."
                    Throw "There are more than one images that match ImageName filter *$Edition"
                }

                ElseIf ( -Not $WindowsImage )
                    
              # No images were found.
                {
                    Write-Error -Message "The specified edition does not appear to exist in the specified WIM."
                    Write-Error -Message "Valid edition names are:"
                    Get-WindowsImage -ImagePath $Path -Verbose:$False
                    Throw
                }

                $Edition       = $WindowsImage.EditionId
                $ImageIndex    = $WindowsImage.ImageIndex    
                $ImageName     = $WindowsImage.ImageName
                $ImageVersion  = New-Object -TypeName "Version" -ArgumentList $WindowsImage.Version
                $ImageLanguage = [System.Globalization.CultureInfo]$WindowsImage.Languages[0]

                Write-Verbose -Message "Image $ImageIndex selected: `“$ImageName`”"
                Write-Debug   -Message "    Image family is $Family, edition is $Edition"
                Write-Debug   -Message "    Image version is $( $ImageVersion.ToString() ), language is $( $ImageLanguage.Name )"

              # Check to make sure that the image we're applying is Windows 7 or greater.
                If ( $ImageVersion -lt $lowestSupportedVersion )
                {
                    If ( $ImageVersion -eq "0.0.0.0" )
                    {
                        Write-Warning -Message "The specified WIM does not encode the Windows version."
                    }
                    Else
                    {
                        Throw "Convert-WindowsImage only supports Windows 8 WIM files and later.  The specified image (version $ImageVersion) does not appear to contain one of those operating systems."
                    }
                }

              # Check to make sure that the image we're applying is RS1 or lower.
                ElseIf ( $ImageVersion -gt $highestTestedVersion )
                {
                    Write-Warning -Message "The version of $scriptName you're using was not tested with this image version."
                    Write-Warning -Message "Please check for an updated script version at http://aka.ms/Convert-WindowsImage."
                }

           #endregion Source Windows image validation

           #region Create and partition Destination disk image

              # Create Disk Image

                $NewDiskImageExParam = @{

                    Path      = $Destination
                    Name      = $Name
                    Format    = $Format
                    Type      = $Type
                    Size      = $Size
                    BlockSize = $BlockSize
                }
                $DestinationImage = New-DiskImageEx @NewDiskImageExParam

              # Attach Disk Image

                Write-Verbose -Message "Attaching $Format"
                $DestinationImage = Mount-DiskImage -InputObject $DestinationImage -PassThru
                $DestinationImage = Get-DiskImage   -ImagePath   $DestinationImage.ImagePath
                $Disk             = Get-Disk -Number $DestinationImage.Number

              # Initialize and partition Disk

                $InitializeDiskExParam = @{

                    Disk           = $Disk
                    PartitionStyle = $PartitionStyle
                    Mount          = $logFolder
                    System         = $System
                    Reserved       = $Reserved
                    Boot           = $Boot
                    Data           = $False  # Having a Data partition is not recommended.
                    Recovery       = $Recovery
                }
                $Partition = Initialize-Disk @InitializeDiskExParam

           #endregion Create and partition Destination disk image

           #region Apply Source Windows image to Destination disk image

                Write-Verbose -Message "Applying image to $Format. This could take a while"

                If (( Get-Command -Name "Expand-WindowsImage" -ErrorAction "SilentlyContinue" ) -and
                    ( -not $ApplyExtendedAttributes -and [string]::IsNullOrEmpty( $Dism ) ))
                {
                    $ExpandWindowsImageParam = @{

                        ApplyPath = $Partition.Boot.AccessPaths[0]
                        ImagePath = $Path
                        Index     = $ImageIndex
                        LogPath   = $DismLog
                        LogLevel  = "WarningsInfo"
                        Verbose   = $False
                    }
                    $WindowsImage = Expand-WindowsImage @ExpandWindowsImageParam
                }
                Else
                {
                    If ( [string]::IsNullOrEmpty( $Dism ) )
                    {
                        $Dism = "dism.exe"
                    }

                    $dismArgs = @(
                            
                        "/Apply-Image"
                        "/ImageFile:`"$Path`""
                        "/Index:$ImageIndex"
                        "/ApplyDir:`"$Partition.Boot.AccessPaths[0]`""
                        "/LogPath:`"$DismLog`""
                    )

                    If ( $ApplyExtendedAttributes )
                    {
                        $dismArgs + "/EA"
                    }

                    Write-Verbose -Message "Applying image: $Dism $dismArgs"

                    $StartProcessExParam = @{

                        FilePath     = $Dism
                        ArgumentList = $dismArgs
                        Log          = $logFolder
                    }
                    $Process = Start-ProcessEx @StartProcessExParam
                }

                Write-Debug -Message "    Image was applied successfully"

              # Copy in the unattend file (if specified by the command line)

                If (-Not [string]::IsNullOrEmpty( $Unattend ))
                {
                    Write-Verbose -Message "Applying unattend file ($(Split-Path $Unattend -Leaf))"

                    $UnattendDestination = Join-Path -Path $Partition.Boot.AccessPaths[0] -ChildPath "unattend.xml"
                    Copy-ItemEx -Path $Unattend -Destination $UnattendDestination -Force
                }

           #endregion Apply Source Windows Image to Destination disk image

           #region Boot configuration

              # Setting $System to $False would explicitly mean that user
              # opted for non-bootable image (e.g. for native VHD boot).
              # In all other cases we need to create the BCD, regardless
              # of partition layout.

                If ( $System )
                {
                    $NewBootConfigurationDatabaseParam = @{

                        Boot   = $Partition.Boot.AccessPaths[0]
                        Locale = $ImageLanguage
                        Log    = $logFolder
                    }

                    If ( $Partition[ "System" ] )
                    {
                        $NewBootConfigurationDatabaseParam.Add(
                            "System", $Partition.System.AccessPaths[0]
                        )
                    }

                    If ( $BcdBoot )
                    {
                        $NewBootConfigurationDatabaseParam.Add(
                            "BcdBoot", $BcdBoot
                        )
                    }

                    $BootConfigurationDatabase =
                        New-BootConfigurationDatabase @NewBootConfigurationDatabaseParam

                  # The following is added to mitigate the VMM diff disk handling
                  # We're going to change from “MbrBootOption” to “LocateBootOption”.

                    $SetBootConfigurationDatabaseParam = @{

                        BootConfigurationDatabase = $BootConfigurationDatabase
                        Locate                    = $True
                        Log                       = $logFolder
                    }

                    If ( $BcdEdit )
                    {
                        $SetBootConfigurationDatabaseParam.Add(
                            "BcdEdit", $BcdEdit
                        )
                    }

                    $BootConfigurationDatabase = 
                        Set-BootConfigurationDatabase @SetBootConfigurationDatabaseParam

                  # Are we turning the debugger on?    

                    If ( $Debugger -inotlike "None" )
                    {
                        $SetBootConfigurationDatabaseParam = @{

                            BootConfigurationDatabase = $BootConfigurationDatabase
                            Debugger                  = $Debugger
                            Log                       = $logFolder
                        }

                        If ( $BcdEdit )
                        {
                            $SetBootConfigurationDatabaseParam.Add(
                                "BcdEdit", $BcdEdit
                            )
                        }

                      # Configure the specified debugging transport and other settings.

                        Switch ( $Debugger )
                        {
                            "Serial"
                            {
                                $SetBootConfigurationDatabaseParam.Add( "ComPort",  $ComPort.Value  )
                                $SetBootConfigurationDatabaseParam.Add( "BaudRate", $BaudRate.Value )
                            }

                            "1394"
                            {
                                $SetBootConfigurationDatabaseParam.Add( "Channel", $Channel.Value)
                            }

                            "USB"
                            {
                                $SetBootConfigurationDatabaseParam.Add( "Target", $Target.Value )
                            }

                            "Network"
                            {
                                $SetBootConfigurationDatabaseParam.Add( "IP",   $IP.Value )
                                $SetBootConfigurationDatabaseParam.Add( "Port", $Port.Value)
                                $SetBootConfigurationDatabaseParam.Add( "Key",  $Key.Value)
                            }
                        }

                        $BootConfigurationDatabase = 
                            Set-BootConfigurationDatabase @SetBootConfigurationDatabaseParam
                    }
                }

                Else
                {
                  # Don't bother to check on debugging.  We can't boot WoA VHDs in VMs, and
                  # if we're native booting, the changes need to be made to the BCD store on the
                  # physical computer's boot volume.

                    Write-Verbose -Message "Image applied. The disk is not bootable."
                }

           #endregion Boot configuration

           #region Additional image enhancements

                If (
                    $Unattend             -or
                    $Merge                -or
                    $RemoteDesktop        -or
                    $NoExpandOnNativeBoot -or
                    $Feature              -or
                    $Driver               -or
                    $Package
                )
                {
                    $SetWindowsImageExParam = @{

                        Path                 = $Partition.Boot.AccessPaths[0]
                        Merge                = $Merge
                        RemoteDesktop        = $RemoteDesktop
                        NoExpandOnNativeBoot = $NoExpandOnNativeBoot
                        Source               = $Source
                        Feature              = $Feature
                        Driver               = $Driver
                        Package              = $Package
                    }

                    If ( $Unattend )
                    {
                        Switch( $Unattend.GetType().ToString() )
                        {
                            "System.String"
                            {
                              # Internally, we store Unattend file as an XML document
                              # so that we can edit its settings individually.

                                [System.Xml.XmlDocument]$Unattend = Get-Content -Path $Unattend
                            }

                            "System.Xml.XmlDocument"
                            {
                              # This is expected. Nothing to change.
                            }

                            Default
                            {
                                Throw "Unexpected value type `“( $Unattend.GetType().ToString() )`” for Unattend parameter"
                            }
                        }

                        $SetWindowsImageExParam.Add( "Unattend", $Unattend )
                    }

                    Set-WindowsImageEx @SetWindowsImageExParam
                }            

           #endregion Additional image enhancements

           #region Image name generation

                If ([String]::IsNullOrEmpty( $NameFinal ))
                {

                  # We need to generate a file name.

                    Write-Verbose -Message "Generating name for $Format"

                  # We cannot use "Get-ItemProperty" here because it will
                  # error on non-existing properties when Strict Mode is
                  # enabled. Hence we use ".GetValue()" instead.

                    $HivePath   = Join-Path -Path $Partition.Boot.AccessPaths[0] -ChildPath "Windows\System32\Config\Software"
                    $Hive       = Mount-RegistryHive -Hive $HivePath
                    $Key        = Get-Item -Path "HKLM:\$($Hive)\Microsoft\Windows NT\CurrentVersion"
                    $buildLabEx = $Key.GetValue( "BuildLabEx" )
                    $Hive       = Dismount-RegistryHive -HiveMountPoint $Hive

                    Write-Debug -Message "    Image build tag:  $buildLabEx"

                  # For some weird compatibility reasons, the native EditionId
                  # property (as present in Image metadata, as well as in the
                  # registry) does not contain Core differentiator, unlike for
                  # Nano erver. However, we will need it in image file name.

                    If ( $InstallationType -eq "Server Core" )
                    {
                        $Edition += "Core"
                    }
                    
                  # Does the image contain VL feature pack?

                    $WindowsPackage = Get-WindowsPackage -Path $Partition.Boot.AccessPaths[0] | Where-Object -FilterScript {
                        $psItem.ReleaseType -eq "FeaturePack" -and
                        $psItem.PackageName -like "*-gvlk-*"
                    } 

                    If ( $WindowsPackage )
                    {
                        Write-Debug -Message "    Image product ID: $ProductId, Volume License"

                        $License = "_vl"
                    }
                    Else
                    {
                        $LIcense = [system.string]::Empty
                    }

                  # Generate the name

                    $NameFinal = "$buildLabEx_$Family_$Edition_$($ImageLanguage.Name)$License.$($Format.ToLower())"
                    Write-Debug -Message "    $Format final name is: `“$NameFinal`”"
                }

           #endregion Image name generation           

           #region Dismount Destination disk image

              # Remove partition access paths, if necessary

                If ( $Partition[ "System" ] )
                {
                    $RemovePartitionAccessPathParam = @{

                        InputObject = $Partition.System
                        AccessPath  = $Partition.System.AccessPaths[0]
                        PassThru    = $True
                    }

                    Write-Debug -Message "    Dismounting System partition"

                    $Partition.System = Remove-PartitionAccessPath @RemovePartitionAccessPathParam

                    $Item = Remove-Item -Path $Partition.System.AccessPaths[0]

                  # When we created System partition on GPT, we had to specify
                  # its type as “Basic data partiton”. This was actually a
                  # workaround for Format, because there's no volume object
                  # on System partition recognized by Windows on GPT disks.
                  # Also, you cannot mount (and even dismount!) such
                  # partitions to NTFS folders. Now, once the partition was
                  # dismounted, we need to change the Partition type to the
                  # proper value (EFI system partition, ESP).
                  # https://msdn.microsoft.com/library/windows/desktop/aa365449

                    If ( $PartitionStyle -eq "GPT" )
                    {
                        $SetPartitionParam = @{
                                    
                            InputObject = $Partition.System
                            GptType     = "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"
                        }

                        Write-Debug -Message "    Setting System partition type to ESP"

                      # Set-Partition does not output any objects and
                      # does not have a “-PassThru” parameter.

                        Set-Partition @SetPartitionParam
                    }

                }

                If ( $Partition[ "Boot" ] )
                {
                    $RemovePartitionAccessPathParam = @{

                        InputObject = $Partition.Boot
                        AccessPath  = $Partition.Boot.AccessPaths[0]
                        PassThru    = $True
                    }

                    Write-Debug -Message "    Dismounting Boot partition"

                    $Partition.Boot = Remove-PartitionAccessPath @RemovePartitionAccessPathParam

                    $Item = Remove-Item -Path $Partition.Boot.AccessPaths[0]
                }

                If ( $Partition[ "Recovery" ] )
                {
                    $RemovePartitionAccessPathParam = @{

                        InputObject = $Partition.Recovery
                        AccessPath  = $Partition.Recovery.AccessPaths[0]
                        PassThru    = $True
                    }

                    Write-Debug -Message "    Dismounting Recovery partition"

                    $Partition.Recovery = Remove-PartitionAccessPath @RemovePartitionAccessPathParam

                    $Item = Remove-Item -Path $Partition.Recovery.AccessPaths[0]
                }

              # Dismount VHD

                Write-Verbose -Message "Closing $Format"

                $DestinationImage = Dismount-DiskImage -InputObject $DestinationImage -PassThru

           #endregion Dismount Destination disk image

           #region Post-process Destination disk image

                $Destination = Join-Path -Path $Destination -ChildPath $NameFinal

                Write-Debug -Message "    $Format final path is: `“$Destination`”"

                If ( Test-Path -Path $Destination )
                {
                    Write-Debug -Message "    Deleting pre-existing image: `“$NameFinal`”"

                    $Item = Remove-Item -Path $Destination -Force
                }

                Write-Debug -Message "    Renaming $Format at `“$Destination`”."

                $Item = Rename-Item -Path $DestinationImage.ImagePath -NewName $NameFinal -PassThru

                If ( $DestinationFinal )
                {
                    $Item = Copy-ItemEx -Path $Destination -Destination $DestinationFinal
                }

                $Destination = $Item.FullName

                Write-Verbose -Message "Successfully created $Destination"

                $vhd += Get-DiskImage -ImagePath $Destination

                $NameFinal        = $Null
                $DestinationImage = $Null

           #endregion Destination disk image
        }
    }
    
    End 
    {
       #region Dismount Source disk image

            Write-Verbose -Message "Dismounting Source disk image"

            $SourceImage = Dismount-DiskImage -InputObject $SourceImage -PassThru

            $SourceImage = $Null

       #endregion Dismont Source disk image

       #region Normal cleanup

            If ( ( Test-Path -Path "Variable:\TempSource" ) -And $CacheSource )
            {
                Write-Verbose -Message "We're cashing Source media at `“$TempSource`”. It will not be deleted"
            }
            Else
            {
                If ( Test-Path -Path $tempSource )
                {
                    Write-Verbose -Message "Removing temporary Source `“$TempSource`”"
                    
                    $Item = Remove-Item -Path $tempSource -Force
                }
            }

            # Close out the transcript and tell the user we're done.

            Write-Verbose -Message "Done."

            If ( $Transcripting )
            {
                $Null = Stop-Transcript
            }

            If ( $Passthru )
            {
                Return $vhd
            }

       #endregion Normal cleanup
    }
}