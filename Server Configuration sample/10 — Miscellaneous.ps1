Invoke-Command -Session $psSession -ScriptBlock {

    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0
    
    Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

    [System.Void](
        New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation' -Name 'AllowProtectedCreds' -PropertyType 'dWord' -Value 1 -Force
    )
}

Invoke-Command -Session $psSession -ScriptBlock {

    Add-LocalGroupMember -Group 'Administrators' -Member @(

        'muthus@microsoft.com'
        'cosdar@microsoft.com'
        'tisaacs@microsoft.com'
        'saisa@microsoft.com'
        'brentf@microsoft.com'
        'jol@microsoft.com'
    )
}

Invoke-Command -Session $psSession -ScriptBlock {

    Get-LocalGroupMember -Group 'Administrators'
}