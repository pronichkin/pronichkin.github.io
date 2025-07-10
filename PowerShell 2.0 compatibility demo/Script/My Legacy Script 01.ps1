$current  = Split-Path -Parent $MyInvocation.MyCommand.Path
$path     = Join-Path -Path $current -ChildPath 'initialize.ps1'
& $path
$object   = New-Object -TypeName 'PowerShell20demo.CompatibilityDemo'

Write-Verbose -Verbose -Message 'Test 1'
Write-Verbose -Verbose -Message 'Try obtaining CAS policy'

$object.GetCasPolicy()