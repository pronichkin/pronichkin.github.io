﻿$FeatureNameDisable = [System.Collections.Generic.List[System.String]]::new()
$FeatureNameEnable  = [System.Collections.Generic.List[System.String]]::new()

    $FeatureNameDisable.Add( 'Bitlocker-Utilities'                               )
  # $FeatureNameDisable.Add( 'CoreFileServer'                                    )
    $FeatureNameDisable.Add( 'FailoverCluster-AdminPak'                          )
    $FeatureNameDisable.Add( 'FailoverCluster-PowerShell'                        )
  # $FeatureNameDisable.Add( 'File-Services'                                     )
    $FeatureNameDisable.Add( 'HCIManagement'                                     )
    $FeatureNameDisable.Add( 'KeyDistributionService-PSH-Cmdlets'                )
    $FeatureNameDisable.Add( 'Microsoft-Hyper-V-Management-PowerShell'           )
    $FeatureNameDisable.Add( 'MicrosoftWindowsPowerShellV2'                      )
    $FeatureNameDisable.Add( 'MSRDC-Infrastructure'                              )
    $FeatureNameDisable.Add( 'PeerDist'                                          )
    $FeatureNameDisable.Add( 'RSAT-Hyper-V-Tools-Feature'                        )
    $FeatureNameDisable.Add( 'ServerManager-Core-RSAT-Role-Tools'                )
    $FeatureNameDisable.Add( 'ServerCore-Drivers-General-WOW64'                  )
    $FeatureNameDisable.Add( 'ServerCoreFonts-NonCritical-Fonts-BitmapFonts'     )
    $FeatureNameDisable.Add( 'ServerCoreFonts-NonCritical-Fonts-MinConsoleFonts' )
    $FeatureNameDisable.Add( 'ServerCoreFonts-NonCritical-Fonts-Support'         )
    $FeatureNameDisable.Add( 'ServerCoreFonts-NonCritical-Fonts-TrueType'        )
    $FeatureNameDisable.Add( 'ServerCoreFonts-NonCritical-Fonts-UAPFonts'        )
    $FeatureNameDisable.Add( 'ServerCore-WOW64'                                  )
    $FeatureNameDisable.Add( 'Server-Psh-Cmdlets'                                )
    $FeatureNameDisable.Add( 'ShieldedVMToolsAdminPack'                          )
    $FeatureNameDisable.Add( 'Storage-Services'                                  )
    $FeatureNameDisable.Add( 'Storage-Replica-AdminPack'                         )
    $FeatureNameDisable.Add( 'SystemInsightsManagement'                          )
    $FeatureNameDisable.Add( 'TlsSessionTicketKey-PSH-Cmdlets'                   )
    $FeatureNameDisable.Add( 'WCF-Services45'                                    )
    $FeatureNameDisable.Add( 'WCF-TCP-PortSharing45'                             )

    $FeatureNameEnable.Add(  'BitLocker'                                         )
  # $FeatureNameEnable.Add(  'Bitlocker-Utilities'                               )
    $FeatureNameEnable.Add(  'CoreFileServer'                                    )  # Required for Dedup 
    $FeatureNameEnable.Add(  'DataCenterBridging'                                )
    $FeatureNameEnable.Add(  'DataCenterBridging-LLDP-Tools'                     )
    $FeatureNameEnable.Add(  'Dedup-Core'                                        )
    $FeatureNameEnable.Add(  'EnhancedStorage'                                   )
  # $FeatureNameEnable.Add(  'FailoverCluster-AdminPak'                          )
    $FeatureNameEnable.Add(  'FailoverCluster-FullServer'                        )
  # $FeatureNameEnable.Add(  'FailoverCluster-PowerShell'                        )
    $FeatureNameEnable.Add(  'File-Services'                                     )  # Parent for Dedup
    $FeatureNameEnable.Add(  'HostGuardian'                                      )
    $FeatureNameEnable.Add(  'Microsoft-Hyper-V'                                 )
  # $FeatureNameEnable.Add(  'Microsoft-Hyper-V-Management-PowerShell'           )
    $FeatureNameEnable.Add(  'Microsoft-Hyper-V-Offline'                         )
    $FeatureNameEnable.Add(  'Microsoft-Hyper-V-Online'                          )
  # $FeatureNameEnable.Add(  'RSAT-Hyper-V-Tools-Feature'                        )
    $FeatureNameEnable.Add(  'ServerManager-Core-RSAT'                           )
    $FeatureNameEnable.Add(  'ServerManager-Core-RSAT-Feature-Tools'             )
  # $FeatureNameEnable.Add(  'ServerManager-Core-RSAT-Role-Tools'                )
  # $FeatureNameEnable.Add(  'ShieldedVMToolsAdminPack'                          )
    $FeatureNameEnable.Add(  'SMBBW'                                             )
    $FeatureNameEnable.Add(  'Storage-Replica'                                   )
  # $FeatureNameEnable.Add(  'Storage-Replica-AdminPack'                         )
    $FeatureNameEnable.Add(  'SystemInsights'                                    )
  # $FeatureNameEnable.Add(  'SystemInsightsManagement'                          )

$FeatureResult = Invoke-Command -Session $psSession -ScriptBlock {

    Disable-WindowsOptionalFeature -Online -FeatureName $using:FeatureNameDisable -NoRestart -WarningAction SilentlyContinue
     Enable-WindowsOptionalFeature -Online -FeatureName $using:FeatureNameEnable  -NoRestart -WarningAction SilentlyContinue
}

$Restart = $FeatureResult | Where-Object -FilterScript {
    $psItem.RestartNeeded
} | Sort-Object -Unique -Property 'psComputerName'

If
(
    $Restart
)
{
    Restart-Computer -ComputerName $Restart.psComputerName -Wait -Force
}