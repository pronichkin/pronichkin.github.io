Set-StrictMode -Version 'Latest'

Function
Stop-swdService
{
 <#
       .Synopsis
        Gracefully terminate Selenium web driver for Edge browser
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [OutputType(
        [System.Void]
    )]

    Param
    (
        [System.Management.Automation.AliasAttribute(
            'Driver'
        )]    
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [OpenQA.Selenium.Edge.EdgeDriver]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Int16]
        $Timeout = 5
    )

    Process
    {
        $WaitCurrent = 0

        While
        (
         # -Not $InputObject.Title
           -Not $InputObject.SessionId
        )
        {
            If
            (
                $WaitCurrent
            )
            {
                $Message = "Web Driver is not responding... $WaitCurrent"
                Write-Message -Channel Debug -Message $Message -Indent 3
            }

            Start-Sleep -Seconds $Timeout

            $WaitCurrent++
        }

      # Stop-SeDriver -Target $InputObject

        $InputObject.Close()
        $InputObject.Quit()
    }
}