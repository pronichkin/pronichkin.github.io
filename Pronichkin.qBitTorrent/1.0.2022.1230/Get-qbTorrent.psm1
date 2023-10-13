using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Get-qbTorrent
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
            Mandatory         = $false,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.AliasAttribute(
            'Torrent'
        )]
        [QBittorrent.Client.TorrentInfo]
      # An existing Torrent object to reobtain (in case we expect it to have changed)
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
      # Display name
        $Name
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # Category name
        $Category
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [QBittorrent.Client.TorrentListFilter]
      # Filter by torrent status
        $Filter
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
      # Completed in the past, including re-downloading
        $Complete
    )

    Begin
    {}

    Process
    {
        $return = [System.Collections.Generic.List[
            QBittorrent.Client.TorrentInfo            
        ]]::new()

       #region    Prepare Query

            $query  = [QBittorrent.Client.TorrentListQuery]::new()
    
            if
            (
                $InputObject
            )
            {
                $query.Hashes = [System.Collections.Generic.List[System.String]]$InputObject.Hash
            }

            if
            (
                $Category
            )
            {
                $query.Category = $Category
            }

            if
            (
                $Filter
            )
            {
                $query.Filter = $Filter
            }

       #endregion Prepare Query

       #region    Standard decoration for invoking asynchronous task

          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_GetTorrentListAsync_QBittorrent_Client_TorrentListQuery_System_Threading_CancellationToken_
            $methodName  = 'GetTorrentListAsync'

            $methodParam = @(
                $query   # query
            )

            $taskParam   = @{
                InputObject = $client
                Name        = $methodName
                Parameter   = $methodParam
            }
          # this should return System.Threading.Tasks.VoidTaskResult
            $result      = Invoke-AsynchronousTask @taskParam

       #endregion Standard decoration for invoking asynchronous task

       #region    Filter output

            if
            (
                $Complete
            )
            {
                $default = [System.DateTimeOffset]::FromUnixTimeSeconds( 0 ).DateTime.ToUniversalTime()

                $result = $result | Where-Object -FilterScript {
                    $psItem.CompletionOn -ne $default
                }
            }

            if
            (
                $Name
            )
            {
                $result = $Name | ForEach-Object -Process {

                    $test = $psItem

                    $result | Where-Object -FilterScript { $psItem.Name -like $test }
                }          
            }

       #endregion Filter output

        $result | ForEach-Object -Process {
            $return.Add( $psItem )
        }

        return $return
    }

    End
    {}
}