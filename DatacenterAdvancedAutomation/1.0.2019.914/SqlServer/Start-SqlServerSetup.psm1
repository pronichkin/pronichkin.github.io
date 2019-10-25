Function
Start-SqlServerSetup
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Path
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.Dictionary[System.String,System.String]]
        $Parameter
    )
   
    Process
    {
        If
        (
            [System.String]::IsNullOrEmpty( $Parameter )
        )
        {
            Write-Verbose -Message "`nThere are no SQL Server actions to perform on this pass.`n`n"
        }
        Else
        {
           #region Variable

                $Argument = [System.Collections.Generic.List[System.String]]::new()

                $Parameter.GetEnumerator() | ForEach-Object -Process {

                    [System.String]$ArgumentCurrent = '/' + $psItem.Key + '="' + $psItem.Value + '"'

                    $Argument.Add( $ArgumentCurrent )
                }

                $Message  = [System.String]::Empty
                $Message += 'Running SQL Server setup with the following parameters'
                Write-Verbose -Message $Message

                Write-Verbose -Message $([System.String]::Empty)
                $Argument | ForEach-Object -Process { Write-Verbose -Message $psItem }
                Write-Verbose -Message $([System.String]::Empty)

           #endregion Variable

           #region Run

                $JoinPathParam = @{
                    
                    Path      = $Path.FullName
                    ChildPath = 'Setup.exe'
                }
                $FilePath = Join-Path @JoinPathParam

                $StartProcessParam = @{

                    FilePath     = $FilePath
                    ArgumentList = $Argument
                    NoNewWindow  = $True
                    Wait         = $True
                    PassThru     = $True
                }
                $Process = Start-Process @StartProcessParam

           #endregion Run

           #region Result

                $Message  = [System.String]::Empty
        
                Switch
                (
                    $Process.ExitCode
                )
                {
                    0
                    {
                        $Message += 'SQL Server setup completed successfully'
                        Write-Verbose -Message $Message
                    }

                    3010
                    {
                        $Message += 'SQL Server setup requires a restart'
                        Write-Warning -Message $Message
                        Restart-Computer -Confirm
                    }

                    Default
                    {
                        $Message += 'SQL Server setup failed '
                        $Message += "and returned unexpected exit code $($Process.ExitCode)."
                        Write-Warning -Message $Message

                        $Path = Get-ChildItem -Path 'C:\Program Files\Microsoft SQL Server' -Filter '1*' | Select-Object -Last 1
                        $Path = Join-Path -Path $Path.FullName -ChildPath 'Setup Bootstrap\Log\Summary.txt'

                        If
                        (
                            Test-Path -Path $Path
                        )
                        {
                            $JoinPathParam = @{

                                Path      = $env:WinDir
                                ChildPath = "System32\Notepad.exe"
                            }
                            $NotepadPath = Join-Path @JoinPathParam
                    
                            $StartProcessParam = @{

                                FilePath     = $NotepadPath
                                ArgumentList = $Path
                                NoNewWindow  = $False
                                Wait         = $False
                                PassThru     = $True
                            }
                            $Process = Start-Process @StartProcessParam
                        }
                    }
                }

           #endregion Result
        }
    }
}