<#
    wrapper for .NET method DNS::GetHostByName
#>

Function
Resolve-dnsNameEx
{

   #region Data

        [cmdletBinding()]

        Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [String[]]
            $Name
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Switch]
            $Reverse
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [Switch]
            $Wait = $True
        ,
            [Parameter(
                Mandatory = $False
            )]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.SwitchParameter]
            $Build
        )

   #endregion Data
   
   #region Code

      # Write-Verbose -Message "Entering Resolve-DnsNameEx for $Name"

        $Module = Import-ModuleEx -Name "DnsClient"

        If
        (
            $Reverse
        )
        {
            $Address = [System.Net.IPAddress[]]@()

            $Name | ForEach-Object -Process {

                $NameCurrent = $psItem

                $AddressCurrent = $null

                $Message = "    Attempting to resolve `“$NameCurrent`” in DNS. If this hangs infinitely, ensure the name is correct!"
                Write-Debug -Message $Message

                While (
                    -Not $AddressCurrent
                )
                {
                    Clear-DnsClientCache

                    $AddressCurrent = Try {
                        [System.Net.Dns]::GetHostByName( $NameCurrent ).AddressList[0]
                    }
                    Catch
                    {
                        Start-Sleep -Seconds 5
                    }
                }
            
                $Address += $AddressCurrent
            }
        }
        ElseIf
        (
            $Wait
        )
        {
            $Address = [String[]]@()

            $Name | ForEach-Object -Process {

                $NameCurrent = $psItem

                $AddressCurrent = [string]::Empty

                If
                (
                    $Build
                )
                {
                    $Message = "    Building the address for `“$NameCurrent`” based on the current user's DNS name"
                    Write-Debug -Message $Message

                    $DomainAddress  = ( $env:UserDnsDomain ).ToLower()
                    $AddressCurrent = $NameCurrent  + "." + $DomainAddress
                }
                Else
                {
                    $Message = "    Attempting to resolve `“$NameCurrent`” in DNS. If this hangs infinitely, ensure the name is correct!"
                    Write-Debug -Message $Message

                    While (
                        -Not $AddressCurrent
                    )
                    {
                        Clear-DnsClientCache

                        $AddressCurrent = Try {
                            [System.Net.Dns]::GetHostByName( $NameCurrent ).HostName
                        }
                        Catch
                        {
                            Start-Sleep -Seconds 5
                        }
                    }
                }
            
                $Address += $AddressCurrent
            }
        }
        Else
        {
            $Address = [String[]]@()

            $Name | ForEach-Object -Process {

                $NameCurrent = $psItem

                $AddressCurrent = [string]::Empty

                Clear-DnsClientCache

                $AddressCurrent = Try {
                    [System.Net.Dns]::GetHostByName( $NameCurrent ).HostName
                }
                Catch
                {
                  # Name not resolvable
                }
            
                $Address += $AddressCurrent
            }
        }

      # Write-Verbose -Message "Exiting Resolve-DnsNameEx for $Name"

        Return $Address

   #endregion Code

}