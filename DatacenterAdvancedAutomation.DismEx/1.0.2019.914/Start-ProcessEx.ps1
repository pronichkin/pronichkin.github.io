<#
    .SYNOPSIS
        Runs an external executable file, and validates the error level.

    .PARAMETER Executable
        The path to the executable to run and monitor.

    .PARAMETER Arguments
        An array of arguments to pass to the executable when it's executed.

    .PARAMETER SuccessfulErrorCode
        The error code that means the executable ran successfully.
        The default value is 0.
#>

Function
Start-ProcessEx
{
    [CmdletBinding()]
    param(
        [Parameter( Mandatory = $True )]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo]
        $FilePath
    ,
        [Parameter( Mandatory = $True )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $ArgumentList
    ,
        [Parameter()]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.DirectoryInfo]
        $Log = $env:Temp
    ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Int32[]]        
        $SuccessfulErrorCode = 0
    )

    Write-Debug -Message "    Running `“$($FilePath.BaseName)`” with parameters: `“$ArgumentList`”"

    $TimeStamp = Get-Date -Format "FileDateTime"

    $StandardOutput = Join-Path -Path $Log.FullName -ChildPath "$($FilePath.BaseName)-$TimeStamp-StandardOutput.txt"
    $StandardError  = Join-Path -Path $Log.FullName -ChildPath "$($FilePath.BaseName)-$TimeStamp-StandardError.txt"

 <# Unfortunately it looks like Powershell's native “Start-Process” cmdlet has 
    some issues when we need both redirect Output channels and capture return
    code. In particular, whenever we specify “-RedirectStandardOutput”
    parameter, we would never get an .ExitCode back. Hence we're using a .NET
    wrapper instead.

    Write-Debug -Message "    Standard output: `“$StandardOutput`”"
    Write-Debug -Message "    Standard error:  `“$StandardError`”"
        
    $StartProcessParam = @{

        FilePath               = $FilePath.FullName
        ArgumentList           = $ArgumentList
        WindowStyle            = "Hidden"
        RedirectStandardOutput = $StandardOutput
        RedirectStandardError  = $StandardError
        Passthru               = $True
    }
    $Process = Start-Process @StartProcessParam
  #>

    $ProcessStartInfo = [System.Diagnostics.ProcessStartInfo]::new( $FilePath.FullName, $ArgumentList )
    
    $ProcessStartInfo.UseShellExecute        = $False
    $ProcessStartInfo.CreateNoWindow         = $True
    $ProcessStartInfo.RedirectStandardOutput = $True
    $ProcessStartInfo.RedirectStandardError  = $True

    $Process = [System.Diagnostics.Process]::Start( $ProcessStartInfo )
    
  # It looks like the object properties are not populated immediately.

    while ( -Not $Process.Path -or $Process.HasExited ) {

        Write-Debug -Message "    Waiting for the process to start"
    }

    $TimeStamp = Get-Date -DisplayHint Time

    Write-Debug -Message "    $TimeStamp started `“$($Process.Path)`”, version `“$($Process.FileVersion)`”"
    
  # It looks like the object properties are not populated immediately.
  # Note: if we'd run using native “Start-Process”, it would hang infinitely
  # here, because Exit Code would never be populated. (Unless we omit the
  # “-RedirectStandardOutput” parameter.)

    while ( $Process.ExitCode -eq $null ) {

        $Wait = $Process.WaitForExit( 1000 )
    }

  # Examine results

    If ( -Not $Process.StandardError.EndOfStream )
    {
        Write-Debug -Message "    Standard error:  `“$StandardError`”"

        $Process.StandardError.ReadToEndAsync().Result | Out-File -FilePath $StandardError
    }

    If ( -Not $Process.StandardOutput.EndOfStream )
    {
        Write-Debug -Message "    Standard output: `“$StandardOutput`”"
            
        $Process.StandardOutput.ReadToEndAsync().Result | Out-File -FilePath $StandardOutput
    }

    $TimeStamp = Get-Date -DisplayHint Time
    
    If ( $Process.ExitCode -in $SuccessfulErrorCode )
    {
        Write-Debug -Message "    $TimeStamp `“$($FilePath.BaseName)`” exited with return code $($Process.ExitCode)"
    }
    Else
    {
        Throw "$TimeStamp `“$($FilePath.BaseName)`” failed with return code $($Process.ExitCode)"
    }

    Return $Process.ExitCode
}