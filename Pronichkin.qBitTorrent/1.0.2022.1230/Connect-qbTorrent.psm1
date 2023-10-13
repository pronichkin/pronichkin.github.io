using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Connect-qbTorrent
{
    [System.Management.Automation.CmdletBindingAttribute(
        DefaultParameterSetName = 'Client'
    )]
    
    [System.Management.Automation.OutputTypeAttribute(
        [QBittorrent.Client.QBittorrentClient]
    )]
    
    Param
    (
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Client',
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
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Address',
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # Address of qBittTorrent server
        $Address   # = [System.Uri]::new( "http://$($computerName)" )
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Client',
            Mandatory         = $true,
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Address',
            Mandatory         = $true,
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.CredentialAttribute()]
        [System.Management.Automation.psCredential]
      # Address of qBittTorrent server
        $Credential = [System.Management.Automation.psCredential]::Empty
    ,
        [System.Management.Automation.ParameterAttribute(
            ParameterSetName  = 'Address',
            Mandatory         = $false,
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Double]
      # Timeout to be used for the newly created connection, in seconds
        $Timeout
    )

    Begin
    {}

    Process
    {
        switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            'Client'
            {
             <# we just re-establish connection to an existing Client instance
                hence no need to create a new instance  #>

                $client = $InputObject
            }

            'Address'
            {
             <# Build a new instance of qBitTorrent Client  #>

                $client = [QBittorrent.Client.QBittorrentClient]::new( $address )

                if
                (
                    $Timeout
                )
                {
                    $client.Timeout = [System.TimeSpan]::FromSeconds( $Timeout )
                }
            }

            default
            {}        
        }

       #region    Standard decoration for invoking asynchronous task
        
          # https://fedarovich.github.io/qbittorrent-net-client-docs/api/QBittorrent.Client.QBittorrentClient.html#QBittorrent_Client_QBittorrentClient_LoginAsync_System_String_System_String_System_Threading_CancellationToken_
            $methodName  = 'LoginAsync'

            $methodParam = @(
                $Credential.UserName                          # username
                $Credential.GetNetworkCredential().Password   # password
            )

            $taskParam   = @{
                InputObject = $client
                Name        = $methodName
                Parameter   = $methodParam
            }
          # this should return System.Threading.Tasks.VoidTaskResult
            $result      = Invoke-AsynchronousTask @taskParam

       #endregion Standard decoration for invoking asynchronous task

        return $client
    }

    End
    {}
}