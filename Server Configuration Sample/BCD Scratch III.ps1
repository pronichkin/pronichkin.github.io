$VerbosePreference = 'Continue' ; $ErrorActionPreference = 'Stop' ; Set-StrictMode -Version 'Latest'
$env:psModulePath = $env:psModulePath + ';C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io'

Import-Module -Name 'Storage' -Verbose:$False
Import-Module -Name 'psBcd'   -Verbose:$False

Set-Location -Path 'C:\Users\artemp.NTDEV\source\repos\pronichkin\pronichkin.github.io\psbcd\1.0.2020.220'

$Store = Get-bcdStore

Get-bcdStore | Get-bcdObject | Show-bcdObject | Format-Table -AutoSize
$Object = Get-bcdStore | Get-bcdObject
Get-bcdObjectElement -Object $Object[0] | Show-bcdObjectElement

$ObjectCurrent = $Object[3]

get-bcdobjectelement -Object $ObjectCurrent
get-bcdobjectelement -Object $ObjectCurrent -Expand
get-bcdobjectelement -Object $ObjectCurrent -Format

get-bcdobject -Store $Store -Id $ObjectCurrent.Id
get-bcdobject -Store $Store -Id $ObjectCurrent.Id -Expand
get-bcdobject -Store $Store -Id $ObjectCurrent.Id -Format | Format-List

$Expanded = get-bcdobject -Store $Store -Id $ObjectCurrent.Id -Expand


  # “PS BCD module” is available from
  # https://github.com/pronichkin/pronichkin.github.io/tree/master/psbcd
    Import-Module -Name 'psBcd' -Verbose:$False

  # Open the BCD store
    $Store  = Get-bcdStore

  # Obtain the Boot Manager object
    $BootManager        = Get-bcdObject -Store $Store -Type 'Windows_boot_manager'

  # Find out which Boot Loader object is the default
    $BootManagerDefault = Get-bcdObjectElement -Object $BootManager -Type 'DefaultObject'

  # Obtain the Boot Loader object
    $BootLoader         = Get-bcdObject -Store $Store -Id $BootManagerDefault.Id

    $BootLoaderF         = Get-bcdObject -Store $Store -Id $BootManagerDefault.Id -Format