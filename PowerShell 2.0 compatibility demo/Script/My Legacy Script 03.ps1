$current  = Split-Path -Parent $MyInvocation.MyCommand.Path
$path     = Join-Path -Path $current -ChildPath 'initialize.ps1'
& $path
$object   = New-Object -TypeName 'PowerShell20demo.CompatibilityDemo'

Write-Verbose -Verbose -Message 'Test 3'
Write-Verbose -Verbose -Message 'Format current date for the US'
$object.GetDate( 'en-US' )

Write-Verbose -Verbose -Message 'Format current date for France'
$object.GetDate( 'fr-FR' )

Write-Verbose -Verbose -Message 'Format current date for... oops, user made a typo'
Write-Verbose -Verbose -Message 'This should be handled gracefully without crashing'
$object.GetDate( 'xx-YY' )