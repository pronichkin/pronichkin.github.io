using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Get-qbTorrentContent
{
    [System.Management.Automation.CmdletBindingAttribute()]
    
    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.List[
            QBittorrent.Client.TorrentContent            
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
      # Torrent to alter
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]        
        [System.String]
      # path of the file
        $Path
    )

    Begin
    {}

    Process
    {
      # Write-Message -Channel Verbose -Message "* "

       #region    Standard decoration for invoking asynchronous task

          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_RenameFileAsync_System_String_System_String_System_String_System_Threading_CancellationToken_
            $methodName  = 'GetTorrentContentsAsync'

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

        if
        (
            $Path
        )
        {
            $result = $result | Where-Object -FilterScript { $psItem.Name -like $Path }
        }

        return $result | Sort-Object -Property 'Name'
    }

    End
    {}
}