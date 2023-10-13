using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Test-qbTorrent
{
    [System.Management.Automation.CmdletBindingAttribute()]
    
    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.List[
            QBittorrent.Client.TorrentInfo            
        ]]
    )]
    
    Param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [QBittorrent.Client.QBittorrentClient]
      # Connection to qBittTorrent server
        $Client
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.AliasAttribute(
            'Torrent'
         )]
        [QBittorrent.Client.TorrentInfo]
      # Torrent to check
        $InputObject
    )

    Begin
    {}

    Process
    {
        Write-Message -Channel Verbose -Message "* Checking`t$($InputObject.Category)`t→`t$($InputObject.Name)"

       #region    Standard decoration for invoking asynchronous task

          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_RecheckAsync_System_String_System_Threading_CancellationToken_
            $methodName  = 'RecheckAsync'

            $methodParam = @(
                $InputObject.Hash  # torrent hash
            )

            $taskParam   = @{
                InputObject = $client
                Name        = $methodName
                Parameter   = $methodParam
            }
          # this should return System.Threading.Tasks.VoidTaskResult
            $result      = Invoke-AsynchronousTask @taskParam

       #endregion Standard decoration for invoking asynchronous task
       
       #region    Wait for the check to start

            $torrent = $null

            while
            (
               -not $torrent -or
                $torrent.State -notIn (
                    [QBittorrent.Client.TorrentState]::CheckingUpload,
                    [QBittorrent.Client.TorrentState]::QueuedForChecking,
                    [QBittorrent.Client.TorrentState]::CheckingResumeData
                )
            )
            {
              # Start-Sleep -Seconds 1

              # reobtain the object in order to check for updated status
                $torrent = $InputObject | Get-qbTorrent -Client $client

                Write-Message -Channel Debug -Indent 1 -Message "Starting check  $($torrent.State)"
            }

       #endregion Wait for the check to start

       #region    Wait for the check to complete

            $torrent = $null

            while
            (
               -not $torrent -or
                $torrent.State -in (
                    [QBittorrent.Client.TorrentState]::CheckingUpload,
                    [QBittorrent.Client.TorrentState]::QueuedForChecking,
                    [QBittorrent.Client.TorrentState]::CheckingResumeData
                )
            )
            {
                Start-Sleep -Seconds 5

              # reobtain the object in order to check for updated status
                $torrent = $InputObject | Get-qbTorrent -Client $client

                Write-Message -Channel Debug -Indent 1 -Message "Waiting check   $($torrent.State)"
            }

       #endregion Wait for the check to complete

       #region    Report check result

            if
            (
              # Good (expected) status

                $torrent.State -in @(
                    [QBittorrent.Client.TorrentState]::StalledUpload
                    [QBittorrent.Client.TorrentState]::PausedUpload
                    [QBittorrent.Client.TorrentState]::ForcedUpload
                    [QBittorrent.Client.TorrentState]::Uploading
                )
            )
            {
                Write-Message -Channel Verbose -Message $torrent.State -Indent 1
                return $true
            }
            elseIf
            (
              # Suboptimal (unexpected) status

                $torrent.State -in @(
                    [QBittorrent.Client.TorrentState]::StalledDownload
                    [QBittorrent.Client.TorrentState]::ForcedDownload
                    [QBittorrent.Client.TorrentState]::PausedDownload
                    [QBittorrent.Client.TorrentState]::Moving
                )
            )
            {
                Write-Message -Channel Warning -Message $torrent.State -Indent 1
                return $false
            }

            else
            {
                throw $torrent.State
            }

       #endregion Report check result
    }

    End
    {}
}