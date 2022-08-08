Function
Get-WindowsBuildNumber
{
    $os = Get-CimInstance -ClassName "Win32_OperatingSystem" -Verbose:$False
    Return [int]($os.BuildNumber)
}