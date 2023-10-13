using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Rename-qbTorrentContent
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
            Mandatory         = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]        
        [System.String]
      # old path of the file
        $oldPath
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # new path to use for the file
        $newPath
    )

    Begin
    {}

    Process
    {
        Write-Message -Channel Verbose -Message "* Renaming`t$oldPath`t→`t$newPath"

       #region    Standard decoration for invoking asynchronous task

          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_RenameFileAsync_System_String_System_String_System_String_System_Threading_CancellationToken_
            $methodName  = 'RenameFileAsync'

            $methodParam = @(
                $InputObject.Hash  # torrent hash
                $oldPath           # old path of the file
                $newPath           # new path to use for the file
            )

            $taskParam   = @{
                InputObject = $client
                Name        = $methodName
                Parameter   = $methodParam
            }
          # this should return System.Threading.Tasks.VoidTaskResult
            $result      = Invoke-AsynchronousTask @taskParam

       #endregion Standard decoration for invoking asynchronous task

        $return = $false

        while
        (
            -not $return
        )
        {
            $return = $InputObject | Get-qbTorrentContent -Client $Client -Path $newPath
        }

        return $return
    }

    End
    {}
}