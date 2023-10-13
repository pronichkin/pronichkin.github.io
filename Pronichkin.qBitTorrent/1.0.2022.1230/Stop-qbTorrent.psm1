using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Stop-qbTorrent
{
    [System.Management.Automation.CmdletBindingAttribute()]
    
    [System.Management.Automation.OutputTypeAttribute(
        [System.Void]
    )]
    
    Param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.AliasAttribute(
            'Client'
        )]
        [QBittorrent.Client.QBittorrentClient]
      # Connection to qBittTorrent server
        $InputObject
    )

    Begin
    {}

    Process
    {
        $client = $InputObject

       #region    Standard decoration for invoking asynchronous task

          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_ShutdownApplicationAsync_System_Threading_CancellationToken_
            $methodName  = 'ShutdownApplicationAsync'

            $taskParam   = @{
                InputObject = $client
                Name        = $methodName
              # Parameter   = $methodParam
            }
          # this should return QBittorrent.Client.ApiVersion
            $result      = Invoke-AsynchronousTask @taskParam

       #endregion Standard decoration for invoking asynchronous task
    }

    End
    {}
}