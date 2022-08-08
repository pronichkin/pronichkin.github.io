Function
Test-WindowsVersion
{
    $isWin8 = ( Get-WindowsBuildNumber ) -ge [int]$lowestSupportedBuild

    Write-Debug -Message "    Is current OS supported?  $isWin8"

    Return $isWin8
}