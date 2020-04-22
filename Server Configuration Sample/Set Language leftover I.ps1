    Get-NetFirewallRule -CimSession $cimSession -Name 'RemoteEventLogSvc-*In-TCP' | Enable-NetFirewallRule


    Get-psSession -ComputerName $ComputerName
    
    $psSession = Disconnect-psSession -Session $psSession
    
    Remove-PSSession -Session $psSession
    
    $psSession  = New-psSession  -ComputerName $ComputerName

    Invoke-Command -Session $psSession -ScriptBlock {

        Get-Culture

        Get-WinHomeLocation

        Get-WinUserLanguageList

        Get-WinDefaultInputMethodOverride

        Get-WinAcceptLanguageFromLanguageListOptOut

        Get-WinCultureFromLanguageListOptOut

        Get-WinLanguageBarOption

        Dism.exe /Online /Get-Intl

        Get-ItemProperty -Path 'hklm:\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters'
    }

    Get-psSession -ComputerName $ComputerName