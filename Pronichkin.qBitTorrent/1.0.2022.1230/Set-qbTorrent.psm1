using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Set-qbTorrent
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
            ValueFromPipeline = $false
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
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.List[
            System.String
        ]]
        $TagAdd
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.List[
            System.String
        ]]
        $TagRemove
    )

    Begin
    {}

    Process
    {
        [System.Collections.Generic.List[
            System.String
        ]]$hash = $InputObject.Hash

        if
        (
            $TagAdd
        )
        {
           #region    Standard decoration for invoking asynchronous task

              # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_AddTorrentTagsAsync_System_Collections_Generic_IEnumerable_System_String__System_Collections_Generic_IEnumerable_System_String__System_Threading_CancellationToken_
                $methodName  = 'AddTorrentTagsAsync'

                $methodParam = @(
                    ,$hash      # torrent hash(es)
                    ,$TagAdd    # tag(s)
                )

                $taskParam   = @{
                    InputObject = $client
                    Name        = $methodName
                    Parameter   = $methodParam
                }
              # this should return System.Threading.Tasks.VoidTaskResult
                $result      = Invoke-AsynchronousTask @taskParam

           #endregion Standard decoration for invoking asynchronous task
        }

        if
        (
            $TagRemove
        )
        {
           #region    Standard decoration for invoking asynchronous task

              # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_AddTorrentTagsAsync_System_Collections_Generic_IEnumerable_System_String__System_Collections_Generic_IEnumerable_System_String__System_Threading_CancellationToken_
                $methodName  = 'DeleteTorrentTagsAsync'

                $methodParam = @(
                    ,$hash         # torrent hash(es)
                    ,$TagRemove    # tag(s)
                )

                $taskParam   = @{
                    InputObject = $client
                    Name        = $methodName
                    Parameter   = $methodParam
                }
              # this should return System.Threading.Tasks.VoidTaskResult
                $result      = Invoke-AsynchronousTask @taskParam

           #endregion Standard decoration for invoking asynchronous task
        }

        return $InputObject | Get-qbTorrent -Client $Client
    }

    End
    {}
}