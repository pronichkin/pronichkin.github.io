Function
Enable-BitLockerEx
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.Host[]]
        $vmHost
    )

    Process
    {
        $vmHost | ForEach-Object -Process {

            $vmHostCurrent = $psItem

            $Session = New-psSession -ComputerName $vmHostCurrent.Name

            $KeyProtector = Invoke-Command -Session $Session -scriptBlock {
                ( Get-BitLockerVolume -MountPoint 'c:' ).KeyProtector
            }

            If
            (
                $KeyProtector
            )
            {
                $Message = "BitLocker is already enabled on $( $vmHostCurrent.Name )"
                Write-Verbose -Message $Message

                $RecoveryPassword = ( $KeyProtector | Where-Object -FilterScript {
                    $psItem.KeyProtectorType -eq 'RecoveryPassword'
                } ).RecoveryPassword | Select-Object -Last 1
            }
            Else
            {
                $Message = "Enabling BitLocker on $( $vmHostCurrent.Name )"
                Write-Verbose -Message $Message

             <# We cannot pass the warning channel output from remote session 
                without diplaying it first in remote session. If we suppress it 
                in the remote session, it won't be passed at all to the local 
                session. If we don't suppress it, it will be displayed 
                regardless of (a) the “Error Action” setting of the local 
                session and (b) the redirection. So instead we suppres it in the
                remote session and immediately output to the default channel so 
                it can be intercepted and parsed in the local session  #>

                $ScriptBlock = {
        
                    $BitLockerParam = @{

                        MountPoint                = 'c:'
                        EncryptionMethod          = 'XtsAes256'
                        RecoveryPasswordProtector = $True
                        WarningAction             = 'SilentlyContinue'
                        WarningVariable           = 'Warning'
                    }        
                    Enable-BitLocker @BitLockerParam

                    $Warning
                }    
    
                $CommandParam = @{

                    Session         = $Session
                    ScriptBlock     = $ScriptBlock
                  # WarningAction   = 'SilentlyContinue'
                  # WarningVariable = 'Warning'
                }    
                $Command = Invoke-Command @CommandParam
    
                $Message = "  BitLocker will be enabled after the next restart"
                Write-Verbose -Message $Message

                $RecoveryPassword = $Command[1].InformationalRecord_Message.Split( "`r`n" )[8]
            }

            Remove-psSession -Session $Session

            $CustomPropertyParam = @{

                Name      = 'Recovery Password'
                vmmServer = $vmHostCurrent.ServerConnection
            }
            $CustomProperty = Get-scCustomProperty @CustomPropertyParam

            $CustomPropertyValueParam = @{

                InputObject    = $vmHostCurrent
                CustomProperty = $CustomProperty
                Value          = $RecoveryPassword
            }
            [System.Void]( Set-scCustomPropertyValue @CustomPropertyValueParam )
        }
    }
}