#region Remote desktop

    $PropertyParamDenyTSConnection = @{

        Path         = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
        Name         = 'fDenyTSConnections'
        Value        =  0
    }

    $PropertyParamCredentialDelegation = @{

        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
        Name         = 'CredentialsDelegation'
        Force        = $True
    }

    $PropertyParamAllowProtectedCred = @{

        Path         = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
        Name         = 'AllowProtectedCreds'
        PropertyType = 'dWord'
        Value        =  1
        Force        = $True
    }

    [System.Void]( Invoke-Command -Session $psSession -ScriptBlock {

        New-Item         @using:PropertyParamCredentialDelegation
        Set-ItemProperty @using:PropertyParamDenyTSConnection
        New-ItemProperty @using:PropertyParamAllowProtectedCred
    } )

    Invoke-Command -Session $psSession -ScriptBlock {
        Start-Service -Name 'TermService'
    }

  # Localization-friendly ID for “Remote Desktop” group
    Enable-NetFirewallRule -CimSession $cimSession -Group '@FirewallAPI.dll,-28752'

#endregion Enable remote desktop

#region Local administrators group

    Invoke-Command -Session $psSession -ScriptBlock {

      # Localization-friendly ID for “Administrators” group
        Add-LocalGroupMember -SID 's-1-5-32-544' -Member @(

            'redmond.corp.microsoft.com\KeplerLabUser'
        )
    }

    Invoke-Command -Session $psSession -ScriptBlock {

        Get-LocalGroupMember -SID 's-1-5-32-544'
    }

#endregion Local administrators group

#region Cluster setting

    $Quorum = Get-ClusterQuorum -InputObject $Cluster

    If
    (
        $Quorum.QuorumResource -and
        $Quorum.QuorumResource.ResourceType.Name -eq 'File Share Witness'
    )
    {
      # No changes needed
    }
    Else
    {
      # $Quorum = Set-ClusterQuorum -InputObject $Cluster -FileShareWitness '\\artemp20w.ntdev.corp.microsoft.com\Witness$'
        $Quorum = Set-ClusterQuorum -InputObject $Cluster -FileShareWitness '\\Kepler003.ntdev.corp.microsoft.com\Witness$'
    }

    $Test = Test-Cluster -InputObject $Cluster

#endregion Cluster setting

#region Hyper-V setting

    $vmHost = [System.Collections.Generic.List[
        Microsoft.HyperV.PowerShell.vmHost
    ]]::new()

    $cimSession | ForEach-Object -Process {

        $Node = Get-ClusterNode -InputObject $Cluster -Name $psItem.ComputerName

        $NodeParam = @{

            InputObject                   = $Node
            Drain                         = $True
            ForceDrain                    = $True
            RetryDrainOnFailure           = $True
            AvoidPlacement                = $False
            Wait                          = $True
            Verbose                       = $False
        }
        $Node    = Suspend-ClusterNode @NodeParam

        $vmHostParam = @{

            CimSession                                = $psItem
            EnableEnhancedSessionMode                 = $True
            NumaSpanningEnabled                       = $False
            VirtualMachineMigrationAuthenticationType =
                [Microsoft.HyperV.PowerShell.MigrationAuthenticationType]::Kerberos
            VirtualMachineMigrationPerformanceOption  =
                [Microsoft.HyperV.PowerShell.vmMigrationPerformance]::SMB
            Passthru                                  = $True
        }
        $vmHost.Add( ( Set-vmHost @vmHostParam ) )

        $Node = Resume-ClusterNode -InputObject $Node -Verbose:$False
    }

#endregion Hyper-V setting