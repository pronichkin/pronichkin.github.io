Function
Get-scLibraryItemEx
{
    [cmdletBinding()]

    Param(

        [parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [parameter(
            Mandatory = $True
        )]
        [ValidateSet(
        
            'CustomResource',
            'Script',
            'VirtualHardDisk'
        )]
        [System.String]
        $Type
    ,
        [parameter(
            Mandatory = $False
        )]
        [Microsoft.SystemCenter.VirtualMachineManager.HostGroup]
        $LibraryGroup
    ,
        [Parameter(
            Mandatory = $False
        )]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        [ValidateNotNullOrEmpty()]
        $vmmServer
    )

    Process
    {
        If
        (
            $LibraryGroup
        )
        {
            $vmmServer = $LibraryGroup.ServerConnection
        }
        ElseIf
        (
            -not $vmmServer
        )
        {
            $Message = 'Please provide VMM Server'
            Write-Error -Message $Message
        }

        [System.Management.Automation.ScriptBlock]$FilterScript = {

            $psItem.Name     -like $Name + '*'      -And
            $psItem.HostType -eq   'LibraryServer'  -And
            $psItem.State    -eq   'Normal'   # Exclude “Missing” or “Orphaned”
        }

        $Item = & Get-sc$Type | Where-Object -FilterScript $FilterScript

        If
        (
            $LibraryGroup
        )
        {
            $Item = $Item | Where-Object -FilterScript {
                $psItem.LibraryGroup -eq $LibraryGroup.Name
            }
        }

        If
        (
            $Item
        )
        {
         <# We cannot just sort by Name or Release (as a string) because for
            example “2” will come later than “11”. Hence we need to only pay
            attention to the last part of “Release” field, known as “Revision”
          #>

            $ReleaseLatest = $Item | ForEach-Object -Process {
                [System.Version]$psItem.Release
            } | Sort-Object -Property 'Revision' | Select-Object -Last 1

            $Item = $Item | Where-Object -FilterScript {
                [System.Version]$psItem.Release -eq $ReleaseLatest
            } | Sort-Object -Property @( 'LibraryGroup', 'LibraryServer' )

            Return $Item
        }
        Else
        {
            $Message = 'Library item could not be located using the specified criteria'
            Write-Verbose -Message $Message
        }
    }
}