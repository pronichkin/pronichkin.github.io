$current  = Split-Path -Parent $MyInvocation.MyCommand.Path
$path     = Join-Path -Path $current -ChildPath 'initialize.ps1'
& $path
$object   = New-Object -TypeName 'PowerShell20demo.CompatibilityDemo'

Write-Verbose -Verbose -Message 'Test 2'
Write-Verbose -Verbose -Message 'Format currency for the US'
$object.GetCurrency( 'en-US', 1234.56 )

Write-Verbose -Verbose -Message 'Format currency for France'
$object.GetCurrency( 'fr-FR', 1234.56 )

Write-Verbose -Verbose -Message 'Format currency for... oops, user made a typo'
Write-Verbose -Verbose -Message 'This should be corrected by using a known default format using a valid currency symbol'
$object.GetCurrency( 'xx-YY', 1234.56 )