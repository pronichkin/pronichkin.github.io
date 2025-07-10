$psVersion  = "{0}.{1}" -f $psVersionTable.psVersion.Major,  $psVersionTable.psVersion.Minor
$bitness    = "$([System.IntPtr]::Size*8)-bit"

if
(
    $psVersionTable[ 'clrVersion' ]
)
{
    $clrVersion = "{0}.{1}" -f $psVersionTable.clrVersion.Major, $psVersionTable.clrVersion.Minor 
    $message = "Running in PowerShell $psVersion, .NET Framework $clrVersion, $bitness"
}
else
{
    $message = "Running in PowerShell $psVersion, .NET Core, $bitness"
}

Write-Verbose -Verbose -Message $message

$current  = Split-Path -Parent $MyInvocation.MyCommand.Path
$path     = Join-Path -Path $current -ChildPath 'PowerShell 2.0 compatibility demo.dll'
Write-Verbose -Verbose -Message "Loading '$path'"
$assembly = [System.Reflection.Assembly]::LoadFrom( $path )

Write-Verbose -Verbose -Message "`n"