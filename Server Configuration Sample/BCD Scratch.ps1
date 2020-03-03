Set-Location -Path 'C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io\psbcd\1.0.2019.1227'

$VerbosePreference     = 'Continue'
$ErrorActionPreference = 'Stop'

Import-Module -Name '.\Get-bcdStore.psm1'
Import-Module -Name '.\Get-bcdObject.psm1'
Import-Module -Name '.\Get-bcdObjectElement.psm1'
Import-Module -Name '.\Set-bcdObjectElementDevicePartitionQualified.psm1'
Import-Module -Name '.\Set-bcdObjectElementDeviceFile.psm1'

