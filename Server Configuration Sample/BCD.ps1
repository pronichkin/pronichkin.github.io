Get-ChildItem -Path 'C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io\psbcd\1.0.2019.1227\*.ps1' | ForEach-Object -Process { . $PSItem.FullName }

$Path  = "$($SystemPartition.AccessPaths[0])efi\microsoft\boot\bcd"
$File  = Get-Item -Path $Path

  # We need to open the BCD store. This operation can only be done locally.
  # It will fail if you try to open remove WMI via cimSession or similar methods.

    $Store  = Get-bcdStore -File $File

  # Boot manager is the general BCD configuration. We need it to find out
  # which Boot loader (OS loading entry) is the default.

  # $BootManager = Get-bcdObject -Store $Store -Type 'Windows boot manager'
    $BootManager = Get-bcdObject -Store $Store -Type Windows_boot_manager
    $BootManager = Get-bcdObject -Store $Store -Id $BootManager.Id

  # These are all elements (properties or settings) of Boot Manager object

    $BootManagerElement = Get-bcdObjectElement -Object $BootManager

  # Now we need to expand the property names from IDs to display values
  # so that we can filter by them and find the entry we need.

  # $BootManagerElementEx = Show-bcdObjectElement -ObjectElement $BootManagerElement

  # Finally, we can filter out the element we need. In this case, it's just a reference
  # to the default Boot Loader entry.

  # $BootManagerDefault = $BootManagerElementEx | Where-Object -FilterScript { $psItem.Keys -eq 'DefaultObject' }

    $BootManagerDefault = Get-bcdObjectElement -Object $BootManager -Type DefaultObject

  # Now we need to obtain the Boot Loader object. We know its ID, so we can filter by it.

    $BootLoader = Get-bcdObject -Store $Store -Type 'Windows boot loader' |
        Where-Object -FilterScript { $psItem.Id -eq $BootManagerDefault.Values }

    $BootLoaderElement   = Get-bcdObjectElement  -Object $BootLoader
    $BootLoaderElementEx = Show-bcdObjectElement -ObjectElement $BootLoaderElement













   # Finally, we can change the setting (set object element value)

     $ElementParam = @{

        Object = $BootLoader
        Type   = 'HypervisorSchedulerType'
        Value  = $using:SchedulerTypeId
    }
    [void]( Set-bcdObjectElement @ElementParam ) 
