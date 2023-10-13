Function
Get-vmGuestExchange
{
 <#
   .Synopsis
        Retrieve a dictionary of Guest exchange items from Hyper-V
        Key-value pair (KVP) exchange component

   .Example
        Get-VM | Get-vmGuestExchange

   .Example
        Get-vmGuestExchange -InputObject $vm -Intrinsic

   .Example
        Get-vmGuestExchange -InputObject $vm -Name 'FullyQualifiedDomainName'

   .Example

        $VMname       = @{ Label = 'VM name'          ;  Expression = { $psItem[ 'VM name'                  ] } }
        $Address      = @{ Label = 'Address'          ;  Expression = { $psItem[ 'FullyQualifiedDomainName' ] } }
        $OSname       = @{ Label = 'OS name'          ;  Expression = { $psItem[ 'OSName'                   ] } }
        $Architecture = @{ Label = 'Architecture'     ;  Expression = {

                Switch ( $psItem[ 'ProcessorArchitecture' ] )
                {
                     0 { 'x86'   }
                     5 { 'arm'   }
                     6 { 'ia64'  }
                     9 { 'x64'   }
                    12 { 'arm64' }
                }
            }
        }
        $OSversion    = @{ Label = 'OS Version'       ;  Expression = { $psItem[ 'OSVersion' ] } }
        $IS           = @{ Label = 'Service Version'  ;  Expression = { $psItem[ 'IntegrationServicesVersion' ] } }

        Get-VM | Get-vmGuestExchange -Intrinsic | Select-Object -Property @(
            $VMname, $Address, $OSname, $Architecture, $OSversion, $IS 
        ) | Format-Table -AutoSize

   .Link
        https://docs.microsoft.com/virtualization/hyper-v-on-windows/reference/integration-services#hyper-v-data-exchange-service-kvp
  #>

    [System.Management.Automation.CmdletBindingAttribute(
        DefaultParameterSetName = 'Service'
    )]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.Dictionary[
            System.String,
            System.String
        ]]
    )]

    Param
    (
        [System.Management.Automation.AliasAttribute( 'vm' )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [Microsoft.HyperV.PowerShell.VirtualMachine]
        $InputObject
    ,
      # https://docs.microsoft.com/windows/win32/hyperv_v2/msvm-kvpexchangedataitem
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Well-known'
        )]
        [System.Management.Automation.ValidateSetAttribute(            
            'CSDVersion',
            'FullyQualifiedDomainName',
            'IntegrationServicesVersion',
            'OSBuildNumber',
            'OSEditionId',
            'OSMajorVersion',
            'OSMinorVersion',
            'OSName',
            'OSPlatformId',
            'OSSignature',
            'OSVendor',
            'OSVersion',
            'ProcessorArchitecture',
            'ProductType',
            'ServicePackMajor',
            'ServicePackMinor',
            'SuiteMask'
        )]
        [System.String]
        $Name
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Intrinsic'
        )]
        [System.Management.Automation.SwitchParameter]
        $Intrinsic
    )

    Begin
    {
      # Find the root module of which the current module is loaded as nested
      # This will be needed to run non-exported functions from this module
        $Module = Get-Module | Where-Object -FilterScript {
            $ExecutionContext.SessionState.Module -in $psItem.NestedModules
        }
    }

    Process
    {
        $Filter = "ElementName = '$( $InputObject.Name )'"

        $InstanceParam = @{
            
            CimSession      = $InputObject.CimSession
          # https://docs.microsoft.com/windows/win32/hyperv_v2/msvm-computersystem
            ClassName       = 'msvm_ComputerSystem'
            Namespace       = 'root/Virtualization/v2'
            Filter          = $Filter
            Verbose         = $False
        }
        $ComputerSystem = Get-CimInstance @InstanceParam

        $AssociatedInstanceParam = @{
            
            CimSession      = $InputObject.CimSession
            InputObject     = $ComputerSystem
          # https://docs.microsoft.com/windows/win32/hyperv_v2/msvm-systemdevice
            Association     = 'msvm_SystemDevice'
          # https://docs.microsoft.com/windows/win32/hyperv_v2/msvm-kvpexchangecomponent
            ResultClassName = 'msvm_KvpExchangeComponent'
            Verbose         = $False
        }
        $ExchangeComponent = Get-CimAssociatedInstance @AssociatedInstanceParam

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {
          # “Guest Exchange Items” pushed by other services running within
          # the guest operating system
            'Service'
            {
                $String = $ExchangeComponent.GuestExchangeItems
            }

          # “Guest Intrinsic Exchange Items” automatically populated
          # by the integration service
            Default
            {
                $String = $ExchangeComponent.GuestIntrinsicExchangeItems
            }
        }

     <# The following expression runs script block in the context of the module,
        where non-exported functions are available. This includes functions
        defined in nested modules. Normally they are only available from the root
        module and not nested modules. Since the current function itself is
        defined in a nested module, it cannot otherwise access non-exported
        functions defined in other nested modules (even of the same root module)
      #>

        $Exchange = & $Module {
            $Args[0]                 | 
          # De-serialize CIM instances from XML
            ConvertFrom-StringXml    | 
          # Parse instance structure and extract all properties
            ConvertFrom-XmlInstance  | 
          # Select only the properties we need
            ConvertFrom-CimProperty
        } $String

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {
          # Return a single value
            'Well-known'
            {
                $psCmdlet.WriteObject( $Exchange[ $Name ] )
            }

          # Return the whole thing
            Default
            {
                $Exchange.Add( 'VM name', $InputObject.Name )

                $psCmdlet.WriteObject( $Exchange )
            }
        }        
    }
}