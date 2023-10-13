Set-StrictMode -Version 'Latest'

Function
Test-Product
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
        [System.String]
        $Version
    )
   
    Process
    {
        $GetCimInstanceParam = @{

            ClassName = 'Win32_Product'
            Filter    = "Name like '$Name%'"
            Verbose   = $False
        }    
        $Product = Get-CimInstance @GetCimInstanceParam

        If
        (
            $Product
        )
        {
            If
            (
                $Version
            )
            {
                If
                (
                    $Product.Version -lt $Version
                )
                {
                    $State = 'InstalledUpdateRequired'
                }
                Else
                {
                    $State = 'InstalledUpdateNotRequired'
                }
            }
            Else
            {
                $State = 'Installed'
            }
        }
        Else
        {
            $State = 'NotInstalled'
        }

        Return $State
    }   
}