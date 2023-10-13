using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Test-qbTorrentConnection
{
    [System.Management.Automation.CmdletBindingAttribute()]
    
    [System.Management.Automation.OutputTypeAttribute(
        [System.Boolean]
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

          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_GetApiVersionAsync_System_Threading_CancellationToken_
            $methodName  = 'GetApiVersionAsync'

            $taskParam   = @{
                InputObject = $client
                Name        = $methodName
              # Parameter   = $methodParam
            }
          # this should return QBittorrent.Client.ApiVersion
            $result      = Invoke-AsynchronousTask @taskParam

       #endregion Standard decoration for invoking asynchronous task

        return [System.Boolean]$result
    }

    End
    {}
}