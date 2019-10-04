Set-StrictMode -Version 'Latest'

Function
Test-SqlServer
{
    [cmdletBinding()]

    Param(
        
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $Version
    )

    Process
    {
        If
        (
            ( Test-Product -Name 'SQL Server' ) -eq 'Installed'
        )
        {
            $NameSpace = Get-cimNameSpaceEx -Path 'root/Microsoft' -Name 'SqlServer'

            If
            (
                $NameSpace   
            )
            {
                $Path = $NameSpace.CimSystemProperties.Namespace + '/' + $NameSpace.Name
            
                If
                (
                    $Version
                )
                {
                    $NameCurrent = "ComputerManagement$Version"
                }
                Else
                {
                    $NameCurrent = "ComputerManagement%"
                }

                $NameSpace = Get-cimNameSpaceEx -Path $Path -Name $NameCurrent

                If
                (
                    $NameSpace
                )
                {
                    $Path = $NameSpace.CimSystemProperties.Namespace + '/' + $NameSpace.Name

                    If
                    (
                        $Name.Contains( '%' )
                    )
                    {
                        $Filter = "DisplayName like '$Name'"
                    }
                    Else
                    {
                        $Filter = "DisplayName = '$Name'"
                    }                

                    $InstanceParam = @{

                        Namespace   = $Path
                        ClassName   = 'SqlService'
                        Filter      = $Filter
                        Verbose     = $False
                    }                        
                    Get-CimInstance @InstanceParam
                }
                Else
                {
                    $Message = 'Specified version of SQL Server is not installed'
                    Write-Warning -Message $Message
                }
            }
            Else
            {
                $Message = 'None of SQL Server services are installed'
                Write-Warning -Message $Message
            }
        }
        Else
        {
            $Message = 'None of SQL Server products are installed'
            Write-Warning -Message $Message
        }
    }
}