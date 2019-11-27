<#
    Start provisioning one virtual machine *asynchronously* on behalf of a user
    This can be potentially be enhanced to consume web-based REST API of Azure 
    Pack instead of calling into VMM directly

    The function sets “Owner” field value to arbitrary string (UPN in 
    user@domain format) to match Azure Pack logic. Hence it requires that VMM 
    connection is opened as “For On Behalf Of.” It does not currently check for
    it, but simply assumes that whoever calls into it (e.g. the 
    “New-scVirtualMachineEx.ps1” script) does establish the correct connection 
    type
#>

Set-StrictMode -Version 'Latest'

Function
New-scVirtualMachineEx
{
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
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Template]
            $Template
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.Cloud]
            $Cloud
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Owner
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.SelfServiceUserRole]
            $Role
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.vmNetwork]
            $Network
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.PortClassification]
            $PortClassification
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $GroupName
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $DomainAddress
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[System.Int64]]
            $OptionalDisk
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $AvailabilitySetName
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Net.IPAddress]
            $IPv4Address
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.VirtualManager.Utils.vmStartAction]
            $StartAction
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.VirtualManager.Utils.vmStopAction]
            $StopAction
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.SystemCenter.VirtualMachineManager.KeyFile]
            $ShieldingData
        )

    Process
    {
        $Message = "Entering New-scVirtualMachineEx for $Name"
      # Write-Debug -Message $Message

       #region Template

                        $Address = Get-scVirtualMachineName -Name $Name -DomainAddress $DomainAddress

                      # $Message = "  $( ( Get-Date -DisplayHint Time ).DateTime )  $Address"

                     <# Normally the VM specialization data (such as computer name)
                        is stored in a temporary “VM Configuration” object which is
                        derived from a generic (reusable) VM template.
                  
                        However, there are certain properties that cannot be defined
                        at Configuration level, and can only be set for a “persistent”
                        object—such as Template or live VM.

                        Here are some examples of such properties

                      * VM Network
                      * Port Classification
                      * Raw Answer File contents (“Unattend Settings” property)
                      * Additional disks

                        We want to dynamically set these properties on per-VM
                        level, hence would create a temporary template.
                        
                        Please note that this temporary template needs to be
                        disposed once the VM is provisioned. Because this
                        function only emits an asynchronous job, it cannot
                        remove the template yet. It needs to be taken care of.
                      #>

                        $TemplateParam = @{

                            Name       = $Address
                            vmTemplate = $Template
                            Owner      = $Owner
                            UserRole   = $Role
                          # vmmServer  = $vmmServer
                        }
                        $TemplateCurrent = New-scvmTemplate @TemplateParam

                      # Connect Virtual Network Adapter to the requested VM Network

                        If
                        (
                            $Network
                        )
                        {
                            $NetworkAdapter = Get-scVirtualNetworkAdapter -vmTemplate $TemplateCurrent

                            $NetworkAdapterParam = @{

                              # IPv4AddressType       = "Static"
                              # MacAddressType        = "Static"
                                vmNetwork             = $Network                    
                              # Synthetic             = $True
                                VirtualNetworkAdapter = $NetworkAdapter
                            }

                          # Get Port Classification

                            If
                            (
                                $PortClassification
                            )
                            {
                                $NetworkAdapterParam.Add(

                                    "PortClassification", $PortClassification
                                )
                            }

                            $NetworkAdapter = Set-scVirtualNetworkAdapter @NetworkAdapterParam
                        }

                      # Custom domain group to local Administrators

                        If
                        (
                            $GroupName
                        )
                        {
                            $UnattendSettings = $TemplateCurrent.UnattendSettings

                            If
                            (
                                [System.String]::IsNullOrWhiteSpace( $DomainAddress )
                            )
                            {
                                $DomainAddress = $env:UserDnsDomain.ToLower()
                            }

                            $UnattendSettings.add(
                                "oobeSystem/Microsoft-Windows-Shell-Setup/UserAccounts/DomainAccounts/DomainAccountList/Domain",
                                $DomainAddress
                            )
                            $UnattendSettings.add(
                                "oobeSystem/Microsoft-Windows-Shell-Setup/UserAccounts/DomainAccounts/DomainAccountList/DomainAccount/Group",
                                "Administrators"
                            )
                            $UnattendSettings.add(
                                "oobeSystem/Microsoft-Windows-Shell-Setup/UserAccounts/DomainAccounts/DomainAccountList/DomainAccount/Name",
                                $GroupName
                            )
                    
                            $Message = "Group `"$DomainAddress\$GroupName`" will be added to Local Administrators."

                            Write-Debug -Message $Message

                            $TemplateCurrent = Set-scvmTemplate -vmTemplate $TemplateCurrent -UnattendSettings $UnattendSettings
                        }

                      # Add disk

                        If
                        (
                            $OptionalDisk
                        )
                        {
                            $Message = "Adding $($OptionalDisk.Count) disk(s)"
                          # Write-Verbose -Message $Message

                            $LunCount = 1

                            $OptionalDisk | ForEach-Object -Process {

                                $Message = "  * $( $psItem / 1gb ) GB"
                              # Write-Verbose -Message $Message

                                $DiskSize = $psItem
                                $FileName = $Address + ' — Disk ' + $LunCount + ' — ' + [System.String]( $DiskSize / 1gb ) + ' GB'

                                $VirtualDiskDriveParam = @{
                
                                    FileName                  = $FileName
                                    VirtualHardDiskSizeMB     = $DiskSize / 1mb
                                  # StorageClassification     = $StorageClassification
                                    VolumeType                = 'None'
                                    Dynamic                   = $True
                                    SCSI                      = $True
                                    Bus                       = 0
                                    LUN                       = $LunCount
                                    VirtualHardDiskFormatType = 'VHDX'
                                  # vm                        = $VirtualMachine
                                    Template                  = $TemplateCurrent
                                }
                                $VirtualDiskDrive = New-scVirtualDiskDrive @VirtualDiskDriveParam

                                $LunCount += 1
                            }
                        }

       #endregion Template

       #region Configuration

                      # VM Configuration

                        $ConfigurationParam = @{

                            Name       = $Address
                            vmTemplate = $TemplateCurrent
                            Cloud      = $Cloud
                        }
                        $Configuration = New-scvmConfiguration @ConfigurationParam

                      # You cannot specify -ComputerName parameter for New-scvmConfiguration
                      # because it is only available for “ComputerTier” paramter set

                        $ConfigurationParam = @{

                            vmConfiguration = $Configuration
                            ComputerName    = $Name
                        }

                      # Tag Availability Set (Cluster Anti-Affinity Class Name)

                        If
                        (
                            $AvailabilitySetName
                        )
                        {        
                            $ConfigurationParam.Add(

                                'AvailabilitySetNames',
                                $AvailabilitySetName
                            )
                        }

                        $Configuration = Set-scvmConfiguration @ConfigurationParam

                      # Virtual Network Adapter Configuration

                        If
                        (
                            $IPv4Address
                        )
                        {
                            $NetworkAdapterConfiguration = Get-scVirtualNetworkAdapterConfiguration -vmConfiguration $Configuration

                            $NetworkAdapterConfigurationParam = @{

                                VirtualNetworkAdapterConfiguration = $NetworkAdapterConfiguration 
                                IPv4Address                        = $IPv4Address.IPAddressToString
                            }
                            $NetworkAdapterConfiguration = Set-scVirtualNetworkAdapterConfiguration @NetworkAdapterConfigurationParam
                        }

       #endregion Configuration

       #region Virtual Machine

            $VirtualMachineParam = @{

                Name              = $Address
                Description       = $Description
                Owner             = $Owner
                UserRole          = $Role
                StartAction       = $StartAction
                StopAction        = $StopAction   
                vmConfiguration   = $Configuration         
              # vmmServer         = $vmmServer
                StartVM           = $True
                RunAsynchronously = $True
            }

            If
            (
                $ShieldingData
            )
            {
                $VirtualMachineParam.Add(
                    'vmShieldingData', $ShieldingData
                )
            }

            New-scVirtualMachine @VirtualMachineParam

       #endregion Virtual Machine

      # Note that there's nothing to return because the VM is not ready yet

        $Message = "Exiting  New-scVirtualMachineEx for $Name"
      # Write-Debug -Message $Message
    }
}