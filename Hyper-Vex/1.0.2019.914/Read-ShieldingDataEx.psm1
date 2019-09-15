Set-StrictMode -Version 'Latest'

Function
Read-ShieldingDataEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'PopulateFromStream'
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.KeyFile]
        $ShieldingData
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'PopulateFromFile'
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]
        $ProvisioningDataKeyFile
    )

    Process
    {
        $ClassParam = @{

            ClassName = 'msps_ProvisioningFileProcessor'
            Namespace = 'root/msps'
            Verbose   = $False
        }
        $Class = Get-CimClass @ClassParam

        $MethodParam = @{
            
            MethodName = $psCmdlet.ParameterSetName
            CimClass   = $Class
            Verbose    = $False
        }

        Switch
        (
            $psCmdlet.ParameterSetName
        )
        {
            'PopulateFromStream'
            {
                $Argument = @{ Data     = $ShieldingData.RawData }                
            }

            'PopulateFromFile'
            {
                $Argument = @{ FilePath = $ProvisioningDataKeyFile.FullName }
            }
        }

        $MethodParam.Add( 'Arguments',  $Argument )

        Return ( Invoke-cimMethod @MethodParam ).ProvisioningFile
    }
}