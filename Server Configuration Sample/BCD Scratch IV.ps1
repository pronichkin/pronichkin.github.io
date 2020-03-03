$env:psModulePath = $env:psModulePath + ';C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io'

Import-Module -Name 'Storage' -Verbose:$False
Import-Module -Name 'psBcd'   -Verbose:$False

$VerbosePreference     = 'Continue'
$DebugPreference       = 'Continue'
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 'Latest'

$BootLabel   = 'Boot'
$SystemLabel = 'System'

$BootVolume   = Get-Volume -FileSystemLabel $BootLabel   | Where-Object -FilterScript { $psItem.DriveType -eq 'Removable' }
$SystemVolume = Get-Volume -FileSystemLabel $SystemLabel | Where-Object -FilterScript { $psItem.DriveType -eq 'Removable' }

$BootPartition   = Get-Partition -Volume $BootVolume
$SystemPartition = Get-Partition -Volume $SystemVolume

$PathParam = @{
    
    Path      = $SystemPartition.AccessPaths[0]
    ChildPath = 'efi\microsoft\boot\bcd'
}
$bcdPath = Join-Path @PathParam

$Item  = Get-Item -Path $bcdPath
$Store = Get-bcdStore -File $Item

$ObjectRaw = Get-bcdObject -Store $Store
$ObjectEx  = Get-bcdObject -Store $Store -Expand
$Object    = Get-bcdObject -Store $Store -Format