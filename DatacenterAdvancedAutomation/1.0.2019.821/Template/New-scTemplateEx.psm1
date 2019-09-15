Function
New-scTemplateEx
{

   #region Data

        [cmdletBinding()]

        Param(
        
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Description
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateSet(
                "vmHost",
                "FileServer"
            )]
            [System.String]
            $Role
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateSet(
                "Compute",
                "Management",
                "Storage",
                "Network"
            )]
            [System.String]
            $ScaleUnitType
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $DomainAddress
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $ProductKey
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $TimeZoneId
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $RegisterUserName
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $OrganizationName
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.StandaloneVirtualHardDisk]
            $VirtualHardDisk
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $SiteName
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $NodeSetName
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateSet(
                "MBR",
                "GPT"
            )]
            [System.String]
            $PartitionStyle
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $DriverMatchingTag
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Script]
            $AnswerFile
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $GuiRunOnceCommands
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Boolean]
            $Guarded
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.CodeIntegrityPolicy]
            $CodeIntegrityPolicy
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Baseline]
            $Baseline
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Hashtable[]]
            $NetworkAdapterGroupProperty
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $Package
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.IO.DirectoryInfo]
            $SoftwareRoot
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $FeatureNameDisable
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $FeatureNameEnable
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountDomainJoin
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountLocal
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Int32]
            $DiskCount
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullorEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountComputerAccess
        )

   #endregion Data

   #region Code

        Write-Verbose -Message "Entering New-scTemplateEx for `“$Name`”"

       #region Define Physical Computer Network Adapter Profile

            $NetworkAdapterProfile =
                [Microsoft.SystemCenter.VirtualMachineManager.PhysicalComputerNetworkAdapterProfile[]]@()

            Write-Verbose -Message "Defining NICs"

          # In Server Types (currently defined in "Set-ClusterEx" script), each
          # "Physical Network Adapter Type" represents a group of similarly
          # configured pNICs.

          # Select only pNICs groups which can be set up during Operating System
          # Deployment (OSD) / Bare-Metal Provisioning (BMP) with VMM.
      
          # For VM Host Servers, these are NICs used for Logical Switches.

          # For Scale-out File Servers (SoFS) it is generic NICs. On OSD/BMP step
          # we only can assign a pNIC to a Logical Network. Teaming and any further
          # configuration will be applied on post-OSD/BMP steps.

            $NetworkAdapterGroupPropertyBmd = 
                $NetworkAdapterGroupProperty | Where-Object -FilterScript {

                    (
                        $psItem.Contains( "LogicalSwitchName" )
                    ) -Or
                    (
                        $psItem.Contains( "LogicalNetworkName" )
                    )
                }

          # Loop through all pNIC groups to define variables which are common to all
          # pNICs in a Group.

            $NetworkAdapterGroupPropertyBmd | ForEach-Object -Process {

                $NetworkAdapterGroupCurrentProperty = $psItem

              # The following properties should be defined for a pNIC Group which
              # belongs to a VM Host Server

                If
                (
                    $NetworkAdapterGroupCurrentProperty.Contains(
                        "LogicalSwitchName"
                    )
                )
                {
                    $NetworkAdapterGroupNameBase =
                        $NetworkAdapterGroupCurrentProperty.LogicalSwitchName

                    $GetScLogicalSwitchParam = @{

                        Name      = $NetworkAdapterGroupNameBase
                        vmmServer = $vmmServer
                    }
                    $LogicalSwitch = Get-scLogicalSwitch @GetScLogicalSwitchParam

                    $Location  = [System.String[]]@()
                    $Location += $SiteName

                    If
                    (
                        $NodeSetName
                    )
                    {
                        $Location += $NodeSetName
                    }

                    $UplinkPortProfileSet = Get-scUplinkPortProfileSetEx -LogicalSwitch $LogicalSwitch -Location $Location -Role $ScaleUnitType

                 <# If
                    (
                        $NetworkAdapterGroupCurrentProperty.LogicalSwitchName -eq "Fabric" -and
                        $NetworkAdapterGroupCurrentProperty -notContains "StaticIpAddressProperty"
                    )
                    {
                      # We will have to select one pNIC as a "Management" network
                      # adapter, as there's no vNICs defined in Physical Computer
                      # Profile. (Now vNIC configuration is moved to Logical Switch
                      # configuration.)

                      # This is currently hardcoded only for the Logical Switch named
                      # "Fabric."

                        $PhysicalComputerNetworkAdapterManagementName =
                            $NetworkAdapterGroupCurrentProperty.Name |
                                Sort-Object | Select-Object -First 1
                    }  #>
                }

              # The following propertiy should be defined for a pNIC Group which 
              # belongs to SoFS 

                If
                (
                    $NetworkAdapterGroupCurrentProperty.Contains(
                        "LogicalNetworkName"
                    )
                )
                {
                    $NetworkAdapterGroupNameBase =
                        $NetworkAdapterGroupCurrentProperty.LogicalNetworkName
                
                    $GetScLogicalNetworkParam = @{

                        Name      = $NetworkAdapterGroupNameBase
                        vmmServer = $vmmServer
                    }
                    $LogicalNetwork = Get-scLogicalNetwork @GetScLogicalNetworkParam
                }

              # Loop through individual pNICs in a Group to create Physical Computer
              # Network Adapter Profiles.

                $NetworkAdapterGroupName = [System.String[]]@()

              # If we do not specify pNIC names in Physical Computer Network Adapter
              # Group Property this means we don't have CDN, and either all adapters
              # are equal, or we specify the "Location." In this case we'd have to
              # build artificial names.

                If
                (
                    $NetworkAdapterGroupCurrentProperty.Contains( 'Name' )
                )
                {
                    $Message = @(
                        "Physical Computer Network Adapter Name was specified explicitly. This is expected if the hardware supports Consistent Device Naming (CDN),"
                        "  or we use PCI `“Bus — Device — Function`” location, or custom `“Slot — Port`” notation, and obtain this information from the BMC directly."
                    )
                    $Message | ForEach-Object -Process { Write-Verbose -Message $psItem }

                    $NetworkAdapterGroupName = $NetworkAdapterGroupCurrentProperty.Name
                }
                ElseIf
                (
                    $NetworkAdapterGroupCurrentProperty.Contains( "Count" )
                )
                {
                    $Message = "Physical Computer Network Adapter Name was calculated based on Count. This is expected if all the physical NICs are euqal."
                    Write-Verbose -Message $Message

                    1,$NetworkAdapterGroupCurrentProperty.Count | ForEach-Object -Process {

                        $NetworkAdapterGroupNameCurrent =
                        $NetworkAdapterGroupNameBase + ' — ' + $psItem
                    
                        $NetworkAdapterGroupName +=
                        $NetworkAdapterGroupNameCurrent
                    }
                }
                ElseIf
                (
                    $NetworkAdapterGroupCurrentProperty.Contains( "Location" )
                )
                {
                  # Looks like this scenario is not implemented. Instead just use “Name” to populate PCI bus location.

                    $Message = "Physical Computer Network Adapter Name was calculated based on Location. This is expected if CDN is not available, and we have different pNICs for different Logical Switches."
                    Write-Verbose -Message $Message

                    $NetworkAdapterGroupCurrentProperty.Location | ForEach-Object -Process {

                        $NetworkAdapterGroupNameCurrent =
                        $NetworkAdapterGroupNameBase + ' — ' + $psItem

                        $NetworkAdapterGroupName +=
                        $NetworkAdapterGroupNameCurrent
                    }
                }

              # Define Physical Computer Network Adapter Profile for each Name

                $NetworkAdapterGroupName | ForEach-Object -Process {

                    $NetworkAdapterProfileCurrentName = $psItem

                  # The following properties are common for all pNIC types.

                    $NetworkAdapterProfileParam = @{
                
                        ConsistentDeviceName        = $NetworkAdapterProfileCurrentName
                        SetAsPhysicalNetworkAdapter = $True
                        vmmServer                   = $vmmServer
                    }
                    
                  # The following properties are different depending of server type

                    If
                    (
                        Test-Path -Path "Variable:\LogicalSwitch"
                    )
    
                  # We're creating a Profile for VM Host server
    
                    {

                        $NetworkAdapterProfileParam.Add(
                    
                            "LogicalSwitch", $LogicalSwitch
                        )
                        $NetworkAdapterProfileParam.Add(

                            "UplinkPortProfileSet", $UplinkPortProfileSet
                        )

                     <# If
                        (
                            ( Test-Path -Path "Variable:\PhysicalComputerNetworkAdapterManagementName" ) -and
                            $NetworkAdapterProfileCurrentName -eq $PhysicalComputerNetworkAdapterManagementName
                        )
                        {
                            $NetworkAdapterProfileParam.Add(
                    
                                "LogicalNetwork", $LogicalNetwork
                            )
                        }  #>
                    }

                    If
                    (
                        Test-Path -Path "Variable:\LogicalNetwork"
                    )

                  # We're creating a Profile for SoFS
    
                    {

                        $NetworkAdapterProfileParam.Add(
                    
                            "LogicalNetwork", $LogicalNetwork
                        )
                        $NetworkAdapterProfileParam.Add(

                            "SetAsGenericNIC", $True
                        )
                        $NetworkAdapterProfileParam.Add(

                            "UseStaticIPForIPConfiguration", $True
                        )
                    }

                    Write-Verbose -Message "Creating Physical Computer Network Adapter Profile for `“$($NetworkAdapterProfileParam.ConsistentDeviceName)`”"

                 <# $NetworkAdapterProfileParam.GetEnumerator() | ForEach-Object -Process {

                        Write-Verbose -Message "  Key:   $($psItem.Key)"
                        Write-Verbose -Message "  Value: $($psItem.Value)"
                    }  #>

                    $NetworkAdapterProfileCurrent =
                        New-scPhysicalComputerNetworkAdapterProfile @NetworkAdapterProfileParam

                    $NetworkAdapterProfile += $NetworkAdapterProfileCurrent
                }

              # If we create a Physical Computer Template for VM Host, the pNIC group
              # is used for a Logical Switch and there will be vNICs in Parent
              # Partition on that Logical Switch, we need to define Physical Computer
              # Network Adapter Profile(s) for those vNICs as well.

                If
                (
                    $NetworkAdapterGroupCurrentProperty.Contains( "StaticIpAddressProperty" )
                )

              # Loop through all vNIC properties for the current Logical Switch

                {
                    $NetworkAdapterGroupCurrentProperty.StaticIpAddressProperty | ForEach-Object -Process {

                        $NetworkAdapterGroupCurrentStaticIpAddressProperty = $psItem

                        $GetScPortClassificationParam = @{

                            Name      = $NetworkAdapterGroupCurrentStaticIpAddressProperty.PortClassificationName
                            vmmServer = $vmmServer
                        }
                        $PortClassification = Get-scPortClassification @GetScPortClassificationParam

                        $GetScvmNetworkParam = @{

                            Name      = $NetworkAdapterGroupCurrentStaticIpAddressProperty.NetworkName
                            vmmServer = $vmmServer
                        }
                        $vmNetwork = Get-scvmNetwork @GetScvmNetworkParam

                        $NetworkAdapterProfileParam = @{ 
                    
                            SetAsVirtualNetworkAdapter    = $True
                            UseStaticIPForIPConfiguration = $True
                            LogicalSwitch                 = $LogicalSwitch
                            PortClassification            = $PortClassification
                            vmNetwork                     = $vmNetwork
                        }

                        If
                        (
                            $NetworkAdapterGroupCurrentStaticIpAddressProperty.Contains( "TransferIpAddress" )
                        )

                      # This would be "Management" vNIC. I.e. it inherits some
                      # properties from a designated pNIC. Thus we need to define
                      # that pNIC a "Transient Management Network Adapter".

                        {
                            $TransientManagementNetworkAdapterName =
                                $NetworkAdapterGroupCurrentProperty.Name |
                                    Select-Object -First 1

                            $TransientManagementNetworkAdapter =
                                $NetworkAdapterProfile |
                                    Where-Object -FilterScript {

                                        $psItem.ConsistentDeviceName -eq $TransientManagementNetworkAdapterName
                                    }

                            $NetworkAdapterProfileParam.Add(

                                "SetAsManagementNic", $True
                            )

                            $NetworkAdapterProfileParam.Add(

                                "TransientManagementNetworkAdapter", $TransientManagementNetworkAdapter
                            )
                        }
                        Else
                        {
                            $NetworkAdapterProfileParam.Add(

                                "SetAsGenericNIC", $True
                            )
                        }

                     <# Write-Verbose -Message "New-scNetworkAdapterProfile"
                    
                        $NetworkAdapterProfileParam.GetEnumerator() | ForEach-Object -Process {

                            Write-Verbose -Message "Key:   $($psItem.Key)"
                            Write-Verbose -Message "Value: $($psItem.Value)"
                        }  #>

                        $NetworkAdapterProfileCurrent =
                            New-scPhysicalComputerNetworkAdapterProfile @NetworkAdapterProfileParam

                        $NetworkAdapterProfile +=
                            $NetworkAdapterProfileCurrent
                    }
                }
            
              # The following values, if needed, should be explicitly re-defined
              # on later iterations

                If
                (
                    Test-Path -Path "Variable:\LogicalSwitch"
                )
                {
                    Remove-Variable -Name "LogicalSwitch"
                }

                If
                (
                    Test-Path -Path "Variable:\UplinkPortProfileSet"
                )
                {
                    Remove-Variable -Name "UplinkPortProfileSet"
                }

                If
                (
                    Test-Path -Path "Variable:\LogicalNetwork"
                )
                {
                    Remove-Variable -Name "LogicalNetwork"
                }
            }

       #endregion Define Physical Computer Network Adapter Profile

       #region Define the rest of Physical Computer Template

            Write-Verbose -Message "Current Local Administrator Credential: `“$RunAsAccountLocal`”"

          # Below is a workardound since currently "New-scPhysicalComputerProfile" 
          # does not accept a Run As Account for "-LocalAdministratorCredential".
          # Instead, it requires explisit "PSCredential" Type, which is unlike
          # "New-scGuestOSProfile". In addition, the "User Name" field should not
          # be blank.            

            $Message = "Physical Computer Templates (profiles) in VMM currently cannot use Run As Accounts. Please provide Local Administrator of Run As Account `“$RunAsAccountLocal`”. Please note that `“User Name`” field should also be populated. The value won't be used — however it will be stored in the properties of Physical Computer Template `“$Name`”."

            Remove-Variable -Name "RunAsAccountLocal"

            $RunAsAccountLocal = Get-Credential -Message $Message            

            Write-Verbose -Message "Creating Physical Computer Template"

            $TemplateParam = @{

                Name                                  = $Name
                Description                           = $Description
                DiskConfiguration                     = "$PartitionStyle=1:PRIMARY:QUICK:4:FALSE:Boot::0:BOOTPARTITION;"
                Domain                                = $DomainAddress
                TimeZone                              = $TimeZoneId
                FullName                              = $RegisterUserName
                OrganizationName                      = $OrganizationName
                ProductKey                            = $ProductKey
                VirtualHardDisk                       = $VirtualHardDisk
                BypassVHDConversion                   = $False
                DomainJoinRunAsAccount                = $RunAsAccountDomainJoin
                LocalAdministratorCredential          = $RunAsAccountLocal
                ComputerAccessRunAsAccount            = $RunAsAccountComputerAccess
                PhysicalComputerNetworkAdapterProfile = $NetworkAdapterProfile
                isGuarded                             = $Guarded
            }

            Switch
            (
                $Role
            )
            {
                "vmHost"
                {
                    $TemplateParam.Add(
                        "UseAsvmHost", $True
                    )
                }
            
                "FileServer"
                {
                    $TemplateParam.Add(
                        "UseAsFileServer", $True
                    )
                }
            }

            If
            (
                $AnswerFile
            )
            {
                $TemplateParam.Add(
                    "AnswerFile", $AnswerFile
                )
            }

            If
            (
                $DriverMatchingTag
            )
            {
                $TemplateParam.Add(
                    "DriverMatchingTag", $DriverMatchingTag
                )
            }

            If
            (
                $GuiRunOnceCommands
            )
            {
                $TemplateParam.Add(
                    "GuiRunOnceCommands", $GuiRunOnceCommands
                )
            }

            If
            (
                $CodeIntegrityPolicy
            )
            {
                $TemplateParam.Add(
                    "CodeIntegrityPolicy", $CodeIntegrityPolicy
                )
            }

            If
            (
                $Baseline
            )
            {
                $TemplateParam.Add(
                    "Baseline", $Baseline
                )
            }

            $Template = New-scPhysicalComputerProfile @TemplateParam

       #endregion Define the rest of Physical Computer Template

       #region Add custom “Post-Deployment” script

            $DeploymentOrder = 1

            $ResourceName = "Clean $DiskCount Disks.cr"

            $Resource = Get-scCustomResource | Where-Object -FilterScript { $psItem.Name -eq $ResourceName }

            If
            (
                -Not $Resource
            )
            {
                $Command = [System.String[]]@()

                0..( $DiskCount -1 ) | ForEach-Object -Process {

                    $Command += "Select Disk $psItem"
                    $Command += "Clean"
                }

                $PathFolder = Join-Path -Path $env:temp -ChildPath "Clean $DiskCount Disks.cr"

                [void]( New-Item -Path $PathFolder -ItemType 'Directory' )

                $PathFile = Join-Path -Path $PathFolder -ChildPath 'DiskPart.script'

                Out-File -FilePath $PathFile -InputObject $Command -Encoding 'ascii'

                $LibraryShare = Get-scLibraryShare -ID $VirtualHardDisk.LibraryShareId

                $LibraryServer = $VirtualHardDisk.LibraryServer
                $LibraryServer = Set-scLibraryServer -LibraryServer $LibraryServer -EnableUnencryptedFileTransfer $True
            
                $Resource = Import-scLibraryPhysicalResource -SourcePath $PathFolder -SharePath $LibraryShare.Path -OverwriteExistingFiles -AllowUnencryptedTransfer

                $LibraryServer = Set-scLibraryServer -LibraryServer $LibraryServer -EnableUnencryptedFileTransfer $False

                Remove-Item -Path $PathFolder -Recurse
            }

            $CommandPath = "%SystemRoot%\System32\DiskPart.exe"

            $CommandParameter  = [System.String]::Empty
            $CommandParameter += " /s"
            $CommandParameter += ' DiskPart.script'

            $ScriptCommandParam = @{

                PhysicalComputerProfile = $Template
                Executable              = $CommandPath
                CommandParameters       = $CommandParameter
                ScriptType              = 'BareMetalPostWinPERegistration'
                LibraryResource         = $Resource
                DeploymentOrder         = $DeploymentOrder
            }
            $ScriptCommand = Add-scScriptCommand @ScriptCommandParam

            $DeploymentOrder++

            If
            (
                $FeatureNameDisable
            )
            {
                $FeatureNameDisableDism = (
                    $FeatureNameDisable | ForEach-Object -Process {
                        '/FeatureName:' + $psItem
                    }
                ) -join ' '

                $CommandPath = "%SystemRoot%\System32\Dism.exe"

                $CommandParameter  = [System.String]::Empty
                $CommandParameter += " /Quiet"
                $CommandParameter += " /NoRestart"
                $CommandParameter += " /Online"
                $CommandParameter += " /Disable-Feature"
                $CommandParameter += " $FeatureNameDisableDism"

                $ScriptCommandParam = @{

                    PhysicalComputerProfile = $Template
                    Executable              = $CommandPath
                    CommandParameters       = $CommandParameter
                    ScriptType              = "BareMetalPostUnattend"
                    DeploymentOrder         = $DeploymentOrder
                }
                $ScriptCommand = Add-scScriptCommand @ScriptCommandParam

                $DeploymentOrder++
            }

            If
            (
                $FeatureNameEnable
            )
            {
                $FeatureNameEnableDism = (
                    $FeatureNameEnable  | ForEach-Object -Process {
                        '/FeatureName:' + $psItem
                    }
                ) -join ' '

                $CommandPath = "%SystemRoot%\System32\Dism.exe"

                $CommandParameter  = [System.String]::Empty
                $CommandParameter += " /Quiet"
                $CommandParameter += " /NoRestart"
                $CommandParameter += " /Online"
                $CommandParameter += " /Enable-Feature"
                $CommandParameter += " $FeatureNameEnableDism"

                $ScriptCommandParam = @{

                    PhysicalComputerProfile = $Template
                    Executable              = $CommandPath
                    CommandParameters       = $CommandParameter
                    ScriptType              = "BareMetalPostUnattend"
                    DeploymentOrder         = $DeploymentOrder
                }
                $ScriptCommand = Add-scScriptCommand @ScriptCommandParam

                $DeploymentOrder++
            }

            If
            (
                $Package
            )
            {
                $Package | ForEach-Object -Process {

                    $PackagePath = Join-Path -Path $SoftwareRoot.FullName -ChildPath $psItem

                    $PackageCurrent = Get-Item -Path $PackagePath

                    Switch
                    (
                        $PackageCurrent.Extension
                    )
                    {
                        ".msi"
                        {
                            $CommandPath = "%SystemRoot%\System32\msiExec.exe"

                            $CommandParameter  = [System.String]::Empty
                            $CommandParameter += " /Passive"
                            $CommandParameter += " /NoRestart"
                            $CommandParameter += " /Package"
                            $CommandParameter += " ""$($PackageCurrent.FullName)"""
                        }

                        Default
                        {
                            $Message = "Unknown package type!"
                            Write-Warning -Message $Message
                        }
                    }

                    $ScriptCommandParam = @{

                        PhysicalComputerProfile = $Template
                        Executable              = $CommandPath
                        CommandParameters       = $CommandParameter
                        ScriptType              = "BareMetalPostConfiguration"
                        DeploymentOrder         = $DeploymentOrder
                    }
                    $ScriptCommand = Add-scScriptCommand @ScriptCommandParam

                    $DeploymentOrder++
                }
            }

       #endregion Add custom “Post-Deployment” script

        Write-Verbose -Message "Exiting  New-scTemplateEx for `“$Name`”"

        Return $Template

   #endregion Code

}