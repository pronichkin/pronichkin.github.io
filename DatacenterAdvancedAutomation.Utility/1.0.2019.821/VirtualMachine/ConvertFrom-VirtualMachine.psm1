Function
ConvertFrom-VirtualMachine
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory        = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.HyperV.PowerShell.VirtualMachine]
        $VirtualMachine
    ,
        [Parameter(
            Mandatory        = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimInstance]
        $ShieldingData
    )

    Process
    {
        $SecurityParam = @{

            vm                                = $VirtualMachine
            EncryptStateAndVmMigrationTraffic = $True
        }
        Set-vmSecurity @SecurityParam

        $KeyProtectorParam = @{
        
            vm                                = $VirtualMachine
            KeyProtector                      = $ShieldingData.KeyProtector
        }
        Set-vmKeyProtector @KeyProtectorParam

        $SecurityPolicyParam = @{
        
            VirtualMachine                    = $VirtualMachine
            PolicyData                        = $ShieldingData.PolicyData
        }
        [System.Void]( Set-vmSecurityPolicyEx @SecurityPolicyParam )

        Enable-vmTPM -vm $VirtualMachine

        Return $VirtualMachine
    }
}