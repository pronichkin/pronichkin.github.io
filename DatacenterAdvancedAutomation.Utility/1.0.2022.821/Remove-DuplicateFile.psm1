$Path = 'E:\Pornography\ea'

$Mode = 'ea'

Get-ChildItem -Path $Path -Force -Recurse | Where-Object -FilterScript { -not $psItem.psIsContainer } | ForEach-Object -Process {

  # Write-Debug -Message $psItem.FullName

    $Directory = $psItem.Directory

    $BaseNasme = ( $psItem.BaseName -split ' \(' )[0]

    $Filter = $BaseNasme + "*" + $psItem.Extension
    $Name   = $BaseNasme       + $psItem.Extension

    If
    (
        $Mode -eq 'ea'
    )
    {
        $Filter = $Filter.Replace( '_4k', [System.String]::Empty ).Replace( '_2160p', [System.String]::Empty )
        $Name   =   $Name.Replace( '_4k', '_2160p' )
    }

    $Item = @( Get-ChildItem -Path $Directory.FullName -Force -Filter $Filter | Where-Object -FilterScript { -not $psItem.psIsContainer } )

    If
    (
        $Item.Count -gt 1
    )
    {
        $Message = "Dupe found for `“$Name`”"
        Write-Verbose -Message $Message

      # Check by size

        $Biggest = $Item | Sort-Object -Property 'Length' | Select-Object -Last 1

        $Item | Where-Object -FilterScript {
            $psItem.Length -lt $Biggest.Length
        } | ForEach-Object -Process {

            $Message = "  Smaller: `“$( $psItem.BaseName )`”"
            Write-Verbose -Message $Message

            Remove-Item -Path $psItem.FullName -Force
        }

      # Check by hash

        $Item = @( Get-ChildItem -Path $Directory.FullName -Force -Filter $Filter | Where-Object -FilterScript { -not $psItem.psIsContainer } )

        If
        (
            $Item.Count -gt 1
        )
        {
            $Hash = [System.Collections.Generic.Dictionary[System.IO.FileInfo, System.String]]::new()

            $Item | Where-Object -FilterScript {
                $psItem.Length -eq $Biggest.Length
            } | ForEach-Object -Process {

                $Message = "  Same size: `“$( $psItem.BaseName )`”"
                Write-Verbose -Message $Message

                $Hash.Add( $psItem, ( Get-FileHash -Path $psItem.FullName ).Hash )
            }

            $Hash.Values | Sort-Object -Unique | ForEach-Object -Process {

                $HashCurrent = $psItem

                $Equal = $Hash.GetEnumerator() | Where-Object -FilterScript { $psItem.Value -eq $HashCurrent } | Sort-Object -Property 'Key'

                $Leave = ( $Equal | Select-Object -Last 1 ).Key

                $Equal | Where-Object -FilterScript { $psItem.Key -ne $Leave } | ForEach-Object -Process {

                    $Dupe = $psItem.Key

                    $Message = "  Dupe: `“$( $Dupe.BaseName )`”"
                    Write-Verbose -Message $Message

                    Remove-Item -Path $Dupe.FullName -Force

                    [System.Void]( $Hash.Remove( $Dupe ) )
                }
            }

            If
            (
                $Hash.Count -gt 1
            )
            {
                $Message = 'The following items are of the same size but different contents:'
                Write-Warning -Message $Message

                $Hash.GetEnumerator() | ForEach-Object -Process {

                    $Message = "  * $( $psItem.Key.BaseName )"
                    Write-Warning -Message $Message
                }
            }
        }

        $Item = @( Get-ChildItem -Path $Directory.FullName -Force -Filter $Filter | Where-Object -FilterScript { -not $psItem.psIsContainer } )

        If
        (
            $Item.Count -eq 1
        )
        {
            $Message = "  New name: $Name"

            Rename-Item -Path $Item.FullName -NewName $Name
        }
    }
}