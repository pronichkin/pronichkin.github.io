Function
Set-HypervisorSchedulerType
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.psSession[]]
        $Session
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateSet(
            'Classic',
            'Core'
        )]
        [System.String]
        $SchedulerType = 'Core'
    )

    Process
    {
        [System.Void]( Import-ModuleEx -Name 'psbcd' )

      # All known Hypervisor Sheduler types

        $HypervisorSchedulerType = @{

            Classic = 0
            Core    = 1
        }

      # The one we selected

        $SchedulerTypeId = $HypervisorSchedulerType[ $SchedulerType ]

      # Perform actual BCD manipulation

        Invoke-Command -Session $Session -scriptBlock {

          # First, we need to load the module. Currently it's very basic list of functions
          # where each function is stored in its own file.

            Get-ChildItem -Path $Using:ModulePath -Filter '*.ps1' | ForEach-Object -Process {

                . $psItem.FullName
            }

          # We need to open the BCD store. This operation can only be done localy.
          # It will fail if you try to open remove WMI via cimSession or similar methods.

            $Store  = Get-bcdStore

          # Boot manager is the general BCD configuration. We need it to find out
          # which Boot loader (OS loading entry) is the default.

            $BootManager = Get-bcdObject -Store $Store -Type 'Windows boot manager'

          # These are all elements (properties or settings) of Boot Manager object

            $BootManagerElement = Get-bcdObjectElement -Object $BootManager

          # Now we need to expand the property names from IDs to display values
          # so that we can filter by them and find the entry we need.

            $BootManagerElementEx = Show-bcdObjectElement -ObjectElement $BootManagerElement

          # Finally, we can filter out the element we need. In this case, it's just a reference
          # to the default Boot Loader entry.

            $BootManagerDefault = $BootManagerElementEx | Where-Object -FilterScript { $psItem.Keys -eq 'DefaultObject' }

          # Now we need to obtain the Boot Loader object. We know its ID, so we can filtr by it.

            $BootLoader = Get-bcdObject -Store $Store -Type 'Windows boot loader' |
                Where-Object -FilterScript { $psItem.Id -eq $BootManagerDefault.Values }

          # Finally, we can change the setting (set object element value)

            $ElementParam = @{

                Object = $BootLoader
                Type   = 'HypervisorSchedulerType'
                Value  = $using:SchedulerTypeId
            }
            [System.Void]( Set-bcdObjectElement @ElementParam )
        }
    }
}