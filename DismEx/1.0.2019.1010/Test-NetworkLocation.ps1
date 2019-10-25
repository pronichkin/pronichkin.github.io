<#
    .SYNOPSIS
        Determines whether or not a given path is a network location or a local drive.

    .DESCRIPTION
        Function to determine whether or not a specified path is a local path, a UNC path,
        or a mapped network drive.

    .PARAMETER Path
        The path that we need to figure stuff out about,
#>

Function
Test-NetworkLocation
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeLine = $true)]
        [string]
        [ValidateNotNullOrEmpty()]
        $Path
    )

    $Result = $False

    If ( ( [System.Uri]$Path ).IsUnc )
    {
        $Result = $True
    }
    Else
    {
        $driveInfo = [System.Io.DriveInfo]( ( Resolve-Path -Path $Path ).Path )

        If ( $driveInfo.DriveType -eq "Network" )
        {
            $Result = $True
        }
    }

    Return $Result
}