$PropertyParamDenyTSConnection = @{

    Path         = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    Name         = 'fDenyTSConnections'
    Value        =  0
}

$PropertyParamAllowProtectedCred = @{

    Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
    Name         = 'AllowProtectedCreds'
    PropertyType = 'dWord'
    Value        =  1
    Force        = $True
}

[System.Void]( Invoke-Command -Session $psSession -ScriptBlock {

    Set-ItemProperty @using:PropertyParamDenyTSConnection
    New-ItemProperty @using:PropertyParamAllowProtectedCred
} )

# Localization-friendly ID for “Remote Desktop” group
Enable-NetFirewallRule -CimSession $cimSession -Group '@FirewallAPI.dll,-28752'

Invoke-Command -Session $psSession -ScriptBlock {

  # Localization-friendly ID for “Administrators” group
    Add-LocalGroupMember -SID 's-1-5-32-544' -Member @(

        'redmond.corp.microsoft.com\KeplerLabUser'
    )
}

Invoke-Command -Session $psSession -ScriptBlock {

    Get-LocalGroupMember -SID 's-1-5-32-544'
}

$Witness = Set-ClusterQuorum -InputObject $Cluster -FileShareWitness '\\artemp20w.ntdev.corp.microsoft.com\Witness$'

$vmHostParam = @{

    CimSession                                = $cimSession
    EnableEnhancedSessionMode                 = $True
    NumaSpanningEnabled                       = $False
    VirtualMachineMigrationAuthenticationType =
        [Microsoft.HyperV.PowerShell.MigrationAuthenticationType]::Kerberos
    VirtualMachineMigrationPerformanceOption  =
        [Microsoft.HyperV.PowerShell.vmMigrationPerformance]::SMB
    Passthru                                  = $True
}
$vmHost = Set-vmHost @vmHostParam