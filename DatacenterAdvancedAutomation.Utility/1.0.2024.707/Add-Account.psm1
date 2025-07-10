# add a domain security principal (user or group)
# to local security group on one or more remote computers

Function
Add-Account
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $False
        )]
        [System.String[]]
        $ComputerName = '.'
    ,
        [Parameter(
            Mandatory = $True
        )]
        [System.String[]]
        $AccountName
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.String]
        $LocalGroupName = 'Administrators'
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.String]
        $DomainAddress = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
    )

    Process
    {
        $ComputerName | ForEach-Object -Process {
    
            $ComputerName1 = $psItem

            $ComputerAddress = If ( $ComputerName1.Contains(".") ) {
                $ComputerName1
            } Else {
                $ComputerName1 + "." + $DomainAddress
            }

            $LocalGroupADSI = [ADSI]"WinNT://$ComputerAddress/$LocalGroupName,group"

            $AccountName | ForEach-Object -Process {

                $AccountName1 = $psItem

                If
                (
                    @( $LocalGroupADSI.Members() ) -And
                    $AccountName1 -in $LocalGroupADSI.Members().Name()
                )
                {
                    $Message = "Account `“$AccountName1`” is already member of `“$LocalGroupName`” on computer `“$ComputerName1`”"
                    Write-Verbose -Message $Message
                }
                Else
                {
                    $Message = "Adding `“$AccountName1`” to `“$LocalGroupName`” on computer `“$ComputerName1`”"
                    Write-Verbose -Message $Message

                    $AccountADSI    = "WinNT://$DomainAddress/$AccountName1" 
                    $LocalGroupADSI.Add($AccountADSI)
                }
            }
        }
    }
}