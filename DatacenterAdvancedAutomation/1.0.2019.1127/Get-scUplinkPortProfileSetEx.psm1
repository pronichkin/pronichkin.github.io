Function
Get-scUplinkPortProfileSetEx
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.LogicalSwitch]
        $LogicalSwitch
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Location
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Role
    )

    Process
    {
        $UplinkPortProfileSet = [System.Collections.Generic.List[
            Microsoft.SystemCenter.VirtualMachineManager.UplinkPortProfileSet
        ]]::new()

        $Location | ForEach-Object -Process {

            $UplinkPortProfileSetName = $LogicalSwitch.Name + ' — ' + $psItem + ' — ' + $Role

            $UplinkPortProfileSetCurrent =
                Get-scUplinkPortProfileSet -vmmServer $LogicalSwitch.ServerConnection |
                    Where-Object -FilterScript {
                        $psItem.Name -like $UplinkPortProfileSetName
                    }

            If
            (
                $UplinkPortProfileSetCurrent
            )
            {
                $UplinkPortProfileSet.Add( $UplinkPortProfileSetCurrent )
            }
         <# If
            (
                $UplinkPortProfileSet
            )
            {
                $Message = "  Obtained Uplink Port Profile set `"$UplinkPortProfileSetName`""
                Write-Verbose -Message $Message
            }
            Else
            {
                $Message = "  Could not find Uplink Port Profile set `"$UplinkPortProfileSetName`""
                Write-Error -Message $Message
            }  #>
        }

        Return $UplinkPortProfileSet
    }
}