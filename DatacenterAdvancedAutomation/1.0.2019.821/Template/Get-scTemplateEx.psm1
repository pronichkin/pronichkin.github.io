Function
Get-scTemplateEx
{

   #region Data

        [cmdletBinding()]

        Param(
        
            [Parameter(
                Mandatory        = $True
            )]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({
                $psItem.GetType().FullName -in @()
                    'Microsoft.SystemCenter.VirtualMachineManager.HardwareProfile'
                    'System.Collections.Hashtable'
            })]
            $HardwareProfile
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [ValidateScript({
                $psItem.GetType().FullName -in @(
                    'Microsoft.SystemCenter.VirtualMachineManager.GuestOsProfile'
                    'System.Collections.Hashtable'
                )
            
            })]
            $OperatingSystemProfile
        ,
            [Parameter(
                ParameterSetName = 'Virtual',
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $InstallationOptionName
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
            [System.String]
            $VirtualHardDiskName
        ,
            [Parameter(
                ParameterSetName = 'Virtual',
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.StorageClassification]
            $StorageClassification
        ,
            [Parameter(
                ParameterSetName = 'Physical',
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountDomainJoin
        ,
            [Parameter(
                ParameterSetName = 'Physical',
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountComputerAccess
        ,
            [Parameter(
                ParameterSetName = 'Physical',
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.RunAsAccount]
            $RunAsAccountLocal
        ,
            [Parameter(
                ParameterSetName = 'Physical',
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.VirtualManager.Remoting.DiscoveredBmcData]
            $Computer
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
            $vmmServer
        )

   #endregion Data

   #region Code

        Write-Verbose -Message "Entering Get-scTemplateEx"

        Switch
        ( $psCmdlet.ParameterSetName )
        {
            'Physical'
            {

              # Build the Name for Physical Computer Template object in VMM

                $TemplateName  = [System.String]::Empty
                $TemplateName += $HardwareProfile.Manufacturer + " "
                $TemplateName += $HardwareProfile.Model + ' — '
                $TemplateName += $SiteName + ' — '

                If
                (
                    $NodeSetName
                )
                {
                    $TemplateName += $NodeSetName + ' — '
                }

                $TemplateName += $OperatingSystemProfile.ScaleUnitType

                Write-Verbose -Message "Template Name: $TemplateName"

              # Look for this object in VMM.

                $TemplateParam = @{
    
                    Name      = $TemplateName
                    vmmServer = $vmmServer
                }
                $Template =
                    Get-scPhysicalComputerProfile @TemplateParam

              # Determine whether we need to create the Profile in VMM

                If
                (
                    $Template
                )

              # The Physical Computer Template was already created in VMM and
              # fetched. We have nothing to do here.

                {
                    Write-Verbose -Message "  Template already exists in VMM!"
                }

                Else

              # We need to create the Physical Computer Template.

                {
                    Write-Verbose -Message "  Existing Template was not found. Creating new Template in VMM"

                  # Note that we'll take the description from Physical Computer OS
                  # Profile. The description from Physical Computer Hardware Profile
                  # will not be used at all.

                    Set-DCAADescription -Define $OperatingSystemProfile

                  # Obtain Virtual Hard Disk from Library with matching Name and 
                  # Partition Style (GPT vs. MBR). Note that the disks in Libary
                  # should be Tagged with relevant Partition style. The most
                  # straightforward of doing that is “Set-scVirtualHardDiskEx.ps1”.

                    $VirtualHardDiskMatchName = Get-scVirtualHardDisk -vmmServer $vmmServer |
                        Where-Object -FilterScript {

                            (
                                $psItem.Name -like "$VirtualHardDiskName*"
                            ) -And
                            (
                                $psItem.Tag -contains $HardwareProfile.PartitionStyle
                            ) -And
                            (
                                $psItem.Shielded -eq $False
                            )
                        }

                    $ReleaseLatest = $VirtualHardDiskMatchName | ForEach-Object -Process {

                        [System.Version]$psItem.Release
                    } | Sort-Object -Property 'Revision' | Select-Object -Last 1

                    $VirtualHardDisk = $VirtualHardDiskMatchName | Where-Object -FilterScript {

                        [System.Version]$psItem.Release -eq $ReleaseLatest
                    }

                    $DriverMatchingTag = @(

                        $HardwareProfile.Manufacturer,
                        $HardwareProfile.Model            
                    )

                  # Create a custom resource with a diskpart script to clean disks
          
                    $FindScComputerExParam = @{

                        bmcAddress      = $Computer.bmcAddress
                        RunAsAccountBmc = $RunAsAccountBmc
                        DeepDiscovery   = $True
                        vmmServer       = $vmmServer
                    }
                    $Computer = Find-scComputerEx @FindScComputerExParam

                  # Build the new Physical Computer Template in VMM. Note that we're
                  # using anohter functhion “New-scTemplateEx”. It's
                  # primary purpose is to parse the information on various network
                  # connections provided in user-frienldy way and construct the
                  # appropriate building blocks for the Profile in VMM.

                    $TemplateParam = @{

                        Name                        = $TemplateName
                        Description                 = $OperatingSystemProfile.Description
                        RegisterUserName            = $OperatingSystemProfile.RegisterUserName
                        OrganizationName            = $OperatingSystemProfile.OrganizationName
                        TimeZoneId                  = $OperatingSystemProfile.TimeZoneId
                        DomainAddress               = $OperatingSystemProfile.DomainAddress
                        ProductKey                  = $OperatingSystemProfile.ProductKey
                        ScaleUnitType               = $OperatingSystemProfile.ScaleUnitType
                        Guarded                     = $OperatingSystemProfile.Guarded
                        DriverMatchingTag           = $DriverMatchingTag
                        Role                        = $HardwareProfile.Role
                        PartitionStyle              = $HardwareProfile.PartitionStyle
                        NetworkAdapterGroupProperty = $HardwareProfile.NetworkAdapterGroupProperty
                        VirtualHardDisk             = $VirtualHardDisk
                        SiteName                    = $SiteName
                        RunAsAccountDomainJoin      = $RunAsAccountDomainJoin
                        RunAsAccountComputerAccess  = $RunAsAccountComputerAccess
                        RunAsAccountLocal           = $RunAsAccountLocal
                        DiskCount                   = $Computer.PhysicalMachine.Disks.Count
                        vmmServer                   = $vmmServer
                    }

                    If
                    (
                        $OperatingSystemProfile.Contains( "AnswerFileName" )
                    )
                    {
                        $GetScScriptParam = @{
        
                            Name      = $OperatingSystemProfile.AnswerFileName
                            vmmServer = $vmmServer
                        }
                        $AnswerFile = Get-scScript @GetScScriptParam

                        $TemplateParam.Add(

                            "AnswerFile", $AnswerFile
                        )
                    }

                    If
                    (
                        $OperatingSystemProfile.Contains( "GuiRunOnceCommands" )
                    )
                    {
                        $TemplateParam.Add(

                            "GuiRunOnceCommands",
                            $OperatingSystemProfile.GuiRunOnceCommands
                        )
                    }

                    If
                    (
                        $OperatingSystemProfile.Guarded
                    )
                    {
                     <# $CodeIntegrityPolicyParam = @{
                
                            vmmServer = $vmmServer
                            Name      = $OperatingSystemProfile.CodeIntegrityPolicyName
                        }
                        $CodeIntegrityPolicy = Get-scCodeIntegrityPolicy @CodeIntegrityPolicyParam  #>

                        $CodeIntegrityPolicyParam = @{
                            
                            Manufacturer = $HardwareProfile.Model
                            Model        = $HardwareProfile.Manufacturer
                            vmmServer    = $vmmServer
                        }
                        $CodeIntegrityPolicy = Get-scCodeIntegrityPolicyEx @CodeIntegrityPolicyParam
                
                        $TemplateParam.Add(

                            "CodeIntegrityPolicy",
                            $CodeIntegrityPolicy
                        )
                    }

                    If
                    (
                        $OperatingSystemProfile[ "BaselineName" ]
                    )
                    {
                        $BaselineParam = @{
                
                            vmmServer = $vmmServer
                            Name      = $OperatingSystemProfile.BaselineName
                        }
                        $Baseline = Get-scBaseline @BaselineParam

                        $TemplateParam.Add(

                            "Baseline",
                            $Baseline
                        )
                    }

                    If
                    (
                        $OperatingSystemProfile[ 'Package' ] -or
                        $HardwareProfile[ 'Package' ]
                    )
                    {
                        $Package =
                            $OperatingSystemProfile[ 'Package' ] +
                            $HardwareProfile[ 'Package' ]

                        $Package = $Package | Where-Object -FilterScript { -Not [System.String]::IsNullOrWhiteSpace( $psItem ) }

                        $TemplateParam.Add(

                            'Package',
                            $Package
                        )

                        $TemplateParam.Add(

                            'SoftwareRoot',
                            $SoftwareRoot
                        )
                    }

                    If
                    (
                        $OperatingSystemProfile[ "FeatureNameDisable" ] -or
                        $HardwareProfile[ "FeatureNameDisable" ]
                    )
                    {
                        $FeatureNameDisable =
                            $OperatingSystemProfile[ "FeatureNameDisable" ] +
                            $HardwareProfile[ "FeatureNameDisable" ]

                        $FeatureNameDisable = $FeatureNameDisable | Where-Object -FilterScript { -Not [System.String]::IsNullOrWhiteSpace( $psItem ) }

                        $TemplateParam.Add(

                            "FeatureNameDisable",
                            $FeatureNameDisable
                        )
                    }

                    If
                    (
                        $OperatingSystemProfile[ "FeatureNameEnable" ] -or
                        $HardwareProfile[ "FeatureNameEnable" ]
                    )
                    {
                        $FeatureNameEnable =
                            $OperatingSystemProfile[ "FeatureNameEnable" ] +
                            $HardwareProfile[ "FeatureNameEnable" ]

                        $FeatureNameEnable = $FeatureNameEnable | Where-Object -FilterScript { -Not [System.String]::IsNullOrWhiteSpace( $psItem ) }

                        $TemplateParam.Add(

                            "FeatureNameEnable",
                            $FeatureNameEnable
                        )
                    }

                    If
                    (
                        $NodeSetName
                    )
                    {
                        $TemplateParam.Add(

                            'NodeSetName',
                            $NodeSetName
                        )
                    }

                    $Template = New-scTemplateEx @TemplateParam
                }
            }

            'Virtual'
            {
                $HardwareProfileNameShort = $HardwareProfile.Name.Replace( ' Generation 2', '' )

                $StorageClassificationNameShort = $StorageClassification.Name.Replace( 'S2D ', '' )

                $TemplateName =
                    $OperatingSystemProfile.Name  + "—" +                 
                    $InstallationOptionName       + "—" +
                    $HardwareProfileNameShort     + "—" +
                    $StorageClassificationNameShort

                $Template = Get-scvmTemplate | Where-Object -FilterScript { $psItem.Name -eq $TemplateName }

                If
                (
                    $Template
                )
                {
                    $Message = "Located existing VM template `“$( $Template.Name )`”"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = "VM template `“$( $Template.Name )`” was not found"
                    Write-Warning -Message $Message
                }
            }
        }

        Write-Verbose -Message "Exiting  Get-scTemplateEx"

        Return $Template
 
   #endregion Code

}