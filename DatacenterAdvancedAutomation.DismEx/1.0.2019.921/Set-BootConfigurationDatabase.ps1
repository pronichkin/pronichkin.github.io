#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Function
Set-BootConfigurationDatabase
{
   #region Data

        [cmdletbinding()]

        Param(
        
            [Parameter( Mandatory = $True )]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.FileInfo[]]
            $BootConfigurationDatabase
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.FileInfo]
            $BcdEdit
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Log = ( Get-Item -Path $env:Temp )
        ,
            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $Locate
        ,
            [Parameter()]
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
        )

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
                                                            9600, 19200,38400, 57600, 115200
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

   #endregion Data

   #region Code

        Process
        {
          # General configuration for BcdEdit execution

            $StartProcessExParam = @{
                                
                FilePath     = [System.String]::Empty  # Placeholder
                Log          = $Log
            }

            If ( $BcdEdit )
            {
                $StartProcessExParam.FilePath = $BcdEdit.FullName
            }
            Else
            {
                $StartProcessExParam.FilePath = "BcdEdit.exe"
            }

          # List of specific parameters for debugger

            If ( $Debugger -inotlike "None" )
            {
                $DbgSetting = @()
        
              # Configure the specified debugging transport and other settings.
                Switch ( $Debugger )
                {
                    "Serial"
                    {
                        $DbgSetting = @(

                            "/dbgsettings SERIAL",
                            "DEBUGPORT:$($ComPort.Value)",
                            "BAUDRATE:$($BaudRate.Value)"
                        )
                    }

                    "1394"
                    {
                        $DbgSetting = @(

                            "/dbgsettings 1394",
                            "CHANNEL:$($Channel.Value)"
                        )
                    }

                    "USB"
                    {
                        $DbgSetting = @(

                            "/dbgsettings USB",
                            "TARGETNAME:$($Target.Value)"
                        )
                    }

                    "Local"
                    {
                        $DbgSetting = @(

                            "/dbgsettings LOCAL"
                        )
                    }

                    "Network"
                    {
                        $DbgSetting = @(

                            "/dbgsettings NET",
                            "HOSTIP:$($IP.Value)",
                            "PORT:$($Port.Value)",
                            "KEY:$($Key.Value)"
                        )
                    }
                }
            }

          # List of settings to be applied to each store

            $BcdEditSet = @()

            If ( $DbgSetting )
            {
                Write-Verbose -Message "Turning kernel debugging on"

                $BcdEditSet += @(

                    "/set `{default`} debug on"  # Enable debugger
                    $DbgSetting                  # Sets global debugger settings
                )
            }

            If ( $Locate )
            {
                Write-Verbose -Message "Fixing the Device ID in the BCD store"

                $BcdEditSet += @(

                    "/set `{bootmgr`} Device Locate"
                    "/set `{default`} Device Locate"
                    "/set `{default`} OsDevice Locate"
                )
            }

          # Execute BcdEdit

            If ( $BcdEditSet )
            {
                $BootConfigurationDatabase | ForEach-Object -Process {

                    $BcdEditStore = @( "/store $( $psItem.FullName )" )

                    $BcdEditSet | ForEach-Object -Process {

                        $BcdEditArg = $BcdEditStore + $psItem
                        $StartProcessExParam.ArgumentList = $BcdEditArg
                        $Process = Start-ProcessEx @StartProcessExParam
                    }
                }
            }
        
            Return $BootConfigurationDatabase
        }        

   #endregion Code
}