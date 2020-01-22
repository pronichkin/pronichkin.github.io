$Command = Invoke-Command -Session $psSession -ScriptBlock {

    Import-Module -Name 'WindowsUpdateProvider' -Verbose:$False

    $VerbosePreference = $Using:VerbosePreference
    $DebugPreference   = $Using:DebugPreference

    Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    Scanning $($env:ComputerName)"

    $Update = Start-wuScan -Verbose:$False

    If
    (
        $Update
    )
    {
        Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    Updates found on $($env:ComputerName)"

        $Update | ForEach-Object -Process {
            Write-Debug -Message "    * $( $psItem.Title )"
        }

        Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    Installing on $($env:ComputerName)"

        [System.Tuple[System.Boolean]]( Install-wuUpdates -Updates $Update -Verbose:$False )
    }
    Else
    {
        Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    No updates found on $($env:ComputerName)"

        [System.Tuple[System.Boolean]]( $False )
    }
}

$Restart = $Command | Where-Object -FilterScript { $psItem.Item1 }

If
(
    $Restart
)
{
    Write-Verbose -Message 'Restarting'

    $Restart.psComputerName | ForEach-Object -Process {
    
        $Message = "  * $psItem"
        Write-Verbose -Message $Message
    }

    Restart-Computer -ComputerName $Restart.psComputerName -Wait -Force
}