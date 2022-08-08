Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Open ImageFap page, check for captcha, retry if needed
#>

Function
Show-ifPage
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Void]
    )]

    param(
    
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [OpenQA.Selenium.Edge.EdgeDriver]
      # Selenium WebDriver
        $Driver
    ,
        [System.Management.Automation.AliasAttribute(
            'Address'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Uri]
      # Address of the page to open
        $InputObject
    )

    process
    {
        $Count  = 0
        $by     = [OpenQA.Selenium.By]::Id( 'captcha' )
        $capcha = $False

        while
        (
           -not $Count                            -or
            ( $capcha -and $capcha[0].Displayed ) -or
            $Driver.Title -notlike '*porn*'
        )
        {
            if
            (
                $Count
            )
            {
                Write-Message -Channel 'Warning' -Message 'Please solve the captcha'

                Start-Sleep -Seconds 30
            }

            $Driver.Navigate().GoToUrl( $psItem )
            $capcha = $Driver.FindElements( $by )

            $Count++
        }
    }
}