Function
Get-WsusUpdateFile
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.UpdateServices.Internal.BaseApi.UpdateServer]
        $WsusServer
        ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Search
    )

    Process
    {
        $WsusServerConfiguration = $WsusServer.GetConfiguration()

        $Search | ForEach-Object -Process {

            $WsusServer.SearchUpdates( $psItem ) | ForEach-Object -Process {

                $File = $psItem.GetInstallableItems().Files
                $File | Where-Object -FilterScript { $psItem.Type -eq "SelfContained" } | ForEach-Object -Process {

                    $Segment = @(

                        $WsusServerConfiguration.LocalContentCachePath
                        $psItem.FileUri.Segments[2]
                        $psItem.FileUri.Segments[3]
                    )

                    $Path = [System.IO.Path]::Combine( [System.String[]]$Segment )
                    $Item = Get-Item -Path $Path
                    Return $Item
                }
            }
        }
    }
}