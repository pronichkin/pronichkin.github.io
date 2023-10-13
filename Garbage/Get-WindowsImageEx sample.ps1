Import-Module -Name 'C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io\DatacenterAdvancedAutomation.Utility'
Import-Module -Name 'C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io\DismEx'

Import-Module -Name 'C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io\DatacenterAdvancedAutomation.Process'

$VerbosePreference     = 'Continue'
$DebugPreference       = 'Continue'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version  'Latest'

$Local = Get-WindowsImageEx
$Local.GetValue( 'ubr' )
$Local.GetValue( 'BuildLab' )
$Local.GetValue( 'BuildLabEx' )

$i  = Get-Item -Path 'D:\Image\SW_DVD9_Win_Server_STD_CORE_1909_64Bit_English_SAC_DC_STD_MLF_X22-17835.ISO'

$Offline = Get-WindowsImageEx -Path $i