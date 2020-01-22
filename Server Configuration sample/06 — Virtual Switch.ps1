$netAdapterName = [System.Collections.Generic.Dictionary[
    System.String,
    System.String
]]::new()

$netAdapterName.Add( 'Intel(R) Ethernet Connection (2) I219-LM', 'Ethernet 1 Top'     )
$netAdapterName.Add( 'Intel(R) I210 Gigabit Network Connection', 'Ethernet 0 Bottom'  )

$netAdapter = Get-NetAdapter -CimSession $cimSession -Physical

$netAdapterName.Keys | ForEach-Object -Process {
    
    $InterfaceDescription = $psItem

    $netAdapter | Where-Object -FilterScript {
        $psItem.InterfaceDescription -eq $InterfaceDescription -and
        $psItem.Name -ne $netAdapterName[ $InterfaceDescription ]
    } | ForEach-Object -Process {
        Rename-NetAdapter -InputObject $psItem -NewName $netAdapterName[ $InterfaceDescription ]
    }
}

$netAdapterBinding = Get-NetAdapterBinding -CimSession $cimSession -InterfaceDescription $netAdapterName.Keys -ComponentID 'vms_pp' | Where-Object -FilterScript { -Not $psItem.Enabled }

$netAdapterBinding | Sort-Object -Unique -Property 'psComputerName' | ForEach-Object -Process {

    $Name = $psItem.psComputerName

    $cimSessionCurrent = $cimSession | Where-Object -FilterScript { $psItem.ComputerName -eq $Name }

    $netAdapterBindingCurrent = $netAdapterBinding | Where-Object -FilterScript { $psItem.psComputerName -eq $Name }

    New-vmSwitch -CimSession $cimSessionCurrent -NetAdapterName $netAdapterBindingCurrent.Name -AllowManagementOS $True -EnableEmbeddedTeaming $True -MinimumBandwidthMode None -Name 'Ethernet'
}