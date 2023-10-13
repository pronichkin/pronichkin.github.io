Function
Get-TimeDifference
{
    [System.Management.Automation.CmdletBindingAttribute()]
    Param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.DateTime]
        $Start
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.DateTime]
        $Finish
 <# ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.String]
        $Action  #>
    )

    Process
    {
        $Difference = $Finish - $Start

        $Hour   = $Difference.Hours.toString()
        $Minute = $Difference.Minutes.toString('D2')
        $Second = $Difference.Seconds.toString('D2')

      # $Message = "$Action took ${Hour}:${Minute}:$Second"
        $Message = "${Hour}:${Minute}:$Second"

        Return $Message
    }
}