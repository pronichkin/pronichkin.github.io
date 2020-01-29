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

 <# -Protocol 'dcom' (which is the default) fails with:
    
   “Fail to retrieve its LastBootUpTime via the WMI service with the following 
    error message: Call was canceled by the message filter.
    (Exception from HRESULT: 0x80010002 (RPC_E_CALL_CANCELED))”
    
    in case computer was never restarted yet
  #>

    Restart-Computer -ComputerName $Restart.psComputerName -Wait -Protocol WSMan -Force
}