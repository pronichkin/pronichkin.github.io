using module '.\Invoke-AsynchronousTask.psm1'

Set-StrictMode -Version 'Latest'

function
Get-qbTorrentLog
{
    [System.Management.Automation.CmdletBindingAttribute()]
    
    [System.Management.Automation.OutputTypeAttribute(
        [System.Object]
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
            ValueFromPipeline = $false
        )]        
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Int32]
        $Count                = [System.Int32]::MaxValue
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
        $Filter
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [QBittorrent.Client.TorrentLogSeverity]
        $Severity           # = [QBittorrent.Client.TorrentLogSeverity]::All
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false, 
            ValueFromPipeline = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Management.Automation.SwitchParameter]
        $Wait
    )

    Begin
    {
      # test connectivity
      # $Client | Test-qbTorrentConnection -Force
    }

    Process
    {
        $useless = @(
            '*The system detected an invalid pointer address in attempting to use a pointer argument in a call'
            '*There is not enough space on the disk'
            '*successfully mapped port using NAT-PMP*'
            'Enqueued to move *'
            '* restored.'
            'Couldn''t download IP geolocation database file*'
            'Detected external IP: *'
            'Successfully listening on IP: *'
            '*Both paths point to the same location.'
            '*added to download list.'
            'Tracker * was added to torrent *'
            'WebAPI login success. IP:*'
            '*Reason: the v2 torrent file has no file tree*'
            'Cancelled moving*'
            '*MDEDiscovery*'
            '*max outstanding piece requests reached'
            '*error: Input/output error'
            '*performance warning: max outstanding piece requests reached*'
            'Restored torrent. Torrent:*'
            '*Performance alert*'
            'Bad Http request, closing socket. IP:*'
        )

        if
        (
            $Wait
        )
        {
            $old = $null

            while
            (
                $true
            )
            {
                $new = Get-qbTorrentLog -Client $client -Filter:$Filter -Count $Count

                if
                (
                    $old -and
                    $old[-1].'Date/Time' -eq $new[-1].'Date/Time'
                )
                {}
                else
                {
                    Clear-Host

                    $new | Format-Table -AutoSize
                }

                $old = $new

                Start-Sleep -Seconds 5
            }        
        }
        else
        {
            $log    = $client.GetLogAsync()
            $record = $log.GetAwaiter().GetResult()

            if
            (
                $log.Status -eq [System.Threading.Tasks.TaskStatus]::RanToCompletion
            )
            {
                if
                (
                    $Severity
                )
                {
                    $record = $record | Where-Object -FilterScript {
                        $psItem.Severity -ge $Severity
                    }
                }

                if
                (
                    $Filter
                )
                {
                    $record = $record | Where-Object -FilterScript {
                        $test = $psItem.Message
                       -not ( $useless | Where-Object -FilterScript {
                            $test -like $psItem
                        } )
                    }
                }
            
                $return = $record | Select-Object -Last $count -Property @(
                    @{
                        Label      = 'Date/Time'
                        Expression = {
                          # [System.DateTimeOffset]::FromUnixTimeMilliseconds( $psItem.Timestamp ).LocalDateTime
                            [System.DateTimeOffset]::FromUnixTimeSeconds( $psItem.Timestamp ).LocalDateTime
                        }
                    },
            
                    'Severity',
                    'Message'
                )
            }
            else
            {
                Write-Warning -Message $log.Status.ToString()

                $return = $null
            }

            return $return
        }
    }

    End
    {}
}