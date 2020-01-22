Function
Start-BitsTransferEx
{
    [CmdletBinding()]

    Param(
    
        [Parameter()]
        [System.Uri]
        $Url
    ,
        [Parameter()]
        [System.IO.DirectoryInfo]
        $Directory = 'E:\Pornography\EA — Bits'
    ,
        [Parameter()]
        [System.Int32]
        $Sample    = 30
    )

    $CrlPath      = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $AssemblyName = 'System.Web.dll'
    $AssemblyPath = Join-Path -Path $CrlPath -ChildPath $AssemblyName

    $Type = Add-Type -Path $AssemblyPath -PassThru

    $Query       = [System.Web.HttpUtility]::ParseQueryString( $Url.Query )

    If
    (
        $Query.AllKeys.Contains( 'validfrom' )
    )
    {
        Write-Verbose -Message 'This is Jules Jordan link'

        $Created     = [System.DateTimeOffset]::FromUnixTimeSeconds( $Query.Get( 'validfrom' ) )
        $Expire      = [System.DateTimeOffset]::FromUnixTimeSeconds( $Query.Get( 'validto'   ) )
        $FileName    = $Url.Segments[ -1 ]
    }
    ElseIf
    (
        $Query.AllKeys.Contains( 'response-content-disposition' )
    )
    {
        Write-Verbose -Message 'This is Evil Angel link'

        $Disposition = $Query.Get( 'response-content-disposition' )

        $FileName = $Disposition.Substring( 21, $Disposition.Length-22 )
    }
    Else
    {
        $FileName = $Url.Segments[ -1 ]
    }
    
    $Destination = Join-Path -Path $Directory -ChildPath $FileName

    If
    (
        Test-Path -Path $Directory
    )
    {
        Write-Verbose -Message 'Downloading to $Directory'
    }
    Else
    {
        $Item = New-Item -Path $Directory -ItemType 'Directory'
    }

    $Transfer = Get-BitsTransfer | Where-Object -FilterScript { $psItem.DisplayName -eq $FileName }

    If
    (
        -Not $Transfer
    )
    {
        $Transfer = Start-BitsTransfer -Source $Url -Destination $Destination -DisplayName $FileName -Asynchronous -Suspended
      
      # bitsadmin.exe /transfer $FileName /dynamic /download /priority FOREGROUND $Url $Destination

      # $Transfer = Get-BitsTransfer -Name $FileName

        bitsadmin.exe /SetCustomHeaders $FileName "User-Agent:Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3851.0 Safari/537.36 Edg/77.0.223.0"

        $Transfer = Resume-BitsTransfer -BitsJob $Transfer -Asynchronous
    }

    $Date = $Transfer.CreationTime
    Write-Verbose -Message $FileName

    If
    (
        $Query.AllKeys.Contains( 'validfrom' )
    )
    {
        Write-Verbose -Message $Url.Segments[ -3 ]
        Write-Verbose -Message "Link valid from $( $Created.LocalDateTime )"
        Write-Verbose -Message "Starting at     $Date"
        Write-Verbose -Message "Link expires at $( $Expire.LocalDateTime )"
    }

    While
    (
        $Transfer.JobState
    )
    {
        $Previous = $Transfer.BytesTransferred
        Start-Sleep -Seconds $Sample

        Switch
        (
            $Transfer.JobState
        )
        {
            'Transferring'
            {
                If
                (
                    -Not ( Test-Path -Path 'variable:\Size' )
                )
                {
                    $Size = [System.Math]::Round( $Transfer.BytesTotal/1mb, 2 )
                    Write-Verbose -Message "$Size MB"
                }

                $Time          = Get-Date -Format t
                $Elapsed       = ( Get-Date ) - $Date
                $ElapsedMinute = [System.Math]::Round( $Elapsed.TotalMinutes )
                $DoneMb        = [System.Math]::Round( $Transfer.BytesTransferred/1MB )
                $SpeedByte     = ( $Transfer.BytesTransferred - $Previous ) / $Sample
                $SpeedBit      = $SpeedByte * 8
                $SpeedMbit     = [System.Math]::Round( $SpeedBit/1000000, 2 )
                $Remain        = $Transfer.BytesTotal - $Transfer.BytesTransferred
                $RemainRound   = [System.Math]::Round( $Remain/1mb )
                
                If
                (
                    $SpeedByte
                )
                {
                    $Eta = [System.Math]::Round( $Remain/$SpeedByte/60 )
                }
                Else
                {
                    $Eta = 'n/a'
                }
                $Left = ( $Expire.LocalDateTime - ( Get-Date ) ).Minutes

                $Message = "$($Time): elapsed $ElapsedMinute munutes, $DoneMb MB done, current speed $SpeedMbit Mbit/s, remaining $RemainRound MB, ETA $Eta munites, link expires in $Left minutes"
                Write-Verbose -Message $Message
            }

	        'Transferred'
            {
                $Taken         = $Transfer.TransferCompletionTime - $Transfer.CreationTime
                $TakenMinute   = [System.Math]::Round( $Taken.TotalMinutes )
                $SpeedByte     = $Transfer.BytesTransferred / $Taken.TotalSeconds
                $SpeedBit      = $SpeedByte * 8
                $SpeedMbit     = [System.Math]::Round( $SpeedBit/1000000, 2 )

                Complete-BitsTransfer -BitsJob $Transfer

                $Message = "Done in $TakenMinute minutes, average speed $SpeedMbit Mbit/s"
                Write-Verbose -Message $Message

                $Return = Get-Item -Path $Destination
            }

            Default
            {
                If
                (
                    [System.String]::IsNullOrWhiteSpace( $Transfer.ErrorDescription )
                )
                {
                    Write-Verbose -Message $Transfer.JobState
                }
                Else
                {
                    Write-Verbose -Message $Transfer.ErrorDescription.Trim()

                    Switch
                    (
                        $Transfer.ErrorDescription.Trim()
                    )
                    {
                        'HTTP status 401: The requested resource requires user authentication.'
                        {
                            Remove-BitsTransfer -BitsJob $Transfer
                            $Return = $Null
                        }

                        'HTTP status 403: The client does not have sufficient access rights to the requested server object.'
                        {
                            Remove-BitsTransfer -BitsJob $Transfer
                            $Return = $Null
                        }

                        Default
                        {
                            $Transfer = Resume-BitsTransfer -BitsJob $Transfer -Asynchronous
                        }
                    }
                }
            }
        }    
    }

    Return $Return
}