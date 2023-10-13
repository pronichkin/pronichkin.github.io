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

Set-StrictMode -Version 'Latest'

Function
Start-ProcessEx
{
    [CmdletBinding()]

    [OutputType([System.Int32])]

    Param(

        [Parameter( Mandatory = $True )]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.FileInfo]
        $FilePath
    ,
        [Parameter( Mandatory = $True )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.String]]
        $ArgumentList
    ,
        [Parameter()]
        [ValidateScript( { Test-Path -Path $psItem.FullName } )]
        [System.Io.DirectoryInfo]
        $Log
    ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.Int32]]
        $SuccessfulExitCode = 0
    )

    Process
    {
        Write-Debug -Message "    Running `“$($FilePath.BaseName)`” with parameters: `“$ArgumentList`”"

        $TimeStamp = Get-Date -Format 'FileDateTime'

        If
        (
            $Log
        )
        {
            $Path = Join-Path -Path $Log.FullName -ChildPath "$($FilePath.BaseName)—$TimeStamp—"
        }
        
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

      # https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo
      # $ProcessStartInfo = [System.Diagnostics.ProcessStartInfo]::new( $FilePath.FullName, $ArgumentList )
        $ProcessStartInfo = [System.Diagnostics.ProcessStartInfo]::new( $FilePath.FullName )
    
        $ProcessStartInfo.UseShellExecute        = $False
        $ProcessStartInfo.CreateNoWindow         = $True        
        $ProcessStartInfo.RedirectStandardOutput = $True
        $ProcessStartInfo.RedirectStandardError  = $True
        $ProcessStartInfo.WindowStyle            =
            [System.Diagnostics.ProcessWindowStyle]::Hidden

        If
        (
            $ArgumentList
        )
        {
            $ProcessStartInfo.Arguments = $ArgumentList -join ' '

          # Write-Debug -Message $ProcessStartInfo.Arguments
        }

      # https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process.start
        $Process = [System.Diagnostics.Process]::Start( $ProcessStartInfo )
    
      # It looks like the object properties are not populated immediately

        While
        (
            -Not ( $Process.Path -or $Process.HasExited )
        )
        {
            Write-Debug -Message '    Waiting for the process to start'
            Start-Sleep -Seconds 1
        }

        $TimeStamp = Get-Date -DisplayHint Time

        $Message = "    $TimeStamp started `“$($Process.Path)`”, version `“$($Process.FileVersion)`”"

        Write-Debug -Message $Message

      # Start reading output

      # $StandardError  = $Process.StandardError.ReadToEnd()
        $StandardError  = $Process.StandardError.ReadToEndAsync()
      # $StandardOutput = $Process.StandardOutput.ReadToEnd()
        $StandardOutput = $Process.StandardOutput.ReadToEndAsync()

        $Process.WaitForExit()

      # [System.Void]( $Process.WaitForExit() )

      # Note: if we'd run using native “Start-Process”, it would hang infinitely
      # here, because Exit Code would never be populated. (Unless we omit the
      # “-RedirectStandardOutput” parameter.)

     <# While
        (
            $Process.ExitCode -eq $Null
        )
        {
            [System.Void]( $Process.WaitForExit( 1000 ) )
        }  #>

        $ExitCode = $Process.ExitCode

        $Process.Close()

        $StandardErrorResult  = $StandardError.Result
        $StandardOutputResult = $StandardOutput.Result

      # Examine results

        If
        (
          # -Not $Process.StandardError.EndOfStream
            $StandardErrorResult
        )
        {
            If
            (
                $Log
            )
            {                
                $StandardErrorPath  = $Path + 'StandardError.txt'
                $StandardErrorResult | Out-File -FilePath $StandardErrorPath                

                $Message = "    Standard error:  `“$StandardErrorPath`”"
                Write-Debug   -Message $Message
            }
                        
          # $Message = $StandardError -Split "`r`n"

            Write-Warning -Message $StandardErrorResult
        }

        If
        (
          # -Not $Process.StandardOutput.EndOfStream
            $StandardOutputResult
        )
        {
            If
            (
                $Log
            )
            {
                $StandardOutputPath = $Path + 'StandardOutput.txt'
                $StandardOutputResult | Out-File -FilePath $StandardOutputPath

                $Message = "    Standard output: `“$StandardOutputPath`”"
                Write-Debug -Message $Message
            }

          # $Message = $StandardOutput -Split "`r`n"

            Write-Information -MessageData $StandardOutputResult
        }

        $TimeStamp = Get-Date -DisplayHint Time
    
        $Message = "    $TimeStamp `“$($FilePath.BaseName)`” exited with return code $ExitCode"
      # $Message = "$TimeStamp `“$($FilePath.BaseName)`” failed with return code $($Process.ExitCode)"

        If
        (
            $ExitCode -in $SuccessfulExitCode
        )
        {
            Write-Debug -Message $Message
        }
        Else
        {
            Write-Error -Message $Message
        }

     <# There's no concept of “Exit code” for PowerShell functions, i.e. you 
        cannot return a numeric value and actual output text at the same time.
        Hence we pass process exit code as the single output value, and
        everything else (actual textual output) goes to Informational channel.
      #>

      # $Host.SetShouldExit( $Process.ExitCode )
      # Exit $Process.ExitCode

        Return $ExitCode
    }
}