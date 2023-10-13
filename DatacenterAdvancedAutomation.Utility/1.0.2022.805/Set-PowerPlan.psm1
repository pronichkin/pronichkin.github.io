Set-StrictMode -Version 'Latest'

Function
Set-PowerPlan
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[Microsoft.Management.Infrastructure.cimSession]]
        $cimSession
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Generic.List[System.Management.Automation.Runspaces.psSession]]
        $psSession
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateSet(
            'Balanced',
            'High performance',
            'Power saver'
        )]
        [System.String]
        $PlanName = 'High performance'
    )

    Begin
    {
        $ImageInfo = Get-WindowsImageInfo -ComputerName $cimSession[0].ComputerName

        $InstanceParam = @{

            Namespace  = 'root/cimv2/power'
            ClassName  = 'win32_PowerPlan'
            Filter     = "ElementName = '$PlanName'"
            cimSession = $cimSession
            Verbose    = $False
        }
        $PowerPlan = Get-CimInstance @InstanceParam
    }

    Process
    {
        If
        (
            $ImageInfo.GetValue( 'ReleaseId' ) -lt 1803
        )
        {
          # We can configure Power Plan using WMI
          
            $PowerPlan | ForEach-Object -Process {

                $ActivateParam = @{

                    MethodName  = 'Activate'
                    CimInstance = $psItem
                    Verbose     = $False
                }
                [System.Void]( Invoke-CimMethod @ActivateParam )
            }
        }
        ElseIf
        (
            $psSession
        )
        {
          # WMI Power Plan activation is broken on RS2+

            $PlanId = [System.Guid]::Parse( $PowerPlan[0].InstanceID.Substring( 20 ) )

            $Command = @(
            
                "powercfg.exe -SetAcValueIndex $($PlanId.Guid) Sub_Processor IdleStateMax 1"
                "powercfg.exe -SetActive $($PlanId.Guid)"
            )

            $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( $Command -join "`n" )

            $InvokeCommandParam = @{

                Session      = $psSession
                ScriptBlock  = $ScriptBlock
            }
            $Command = Invoke-Command @InvokeCommandParam
        }
        Else
        {
            $Message = 'The remote computer runs Windows version 1703 or later, but PowerShell session was not provided'
            Write-Warning -Message $Message
        }
    }

    End
    {
        Return Get-CimInstance @InstanceParam
    }
}