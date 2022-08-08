Set-StrictMode -Version 'Latest'

Function
Start-swdService
{
 <#
       .Synopsis
        Initialize Selenium web driver for Edge browser
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [OutputType(
        [OpenQA.Selenium.Edge.EdgeDriver]
    )]

    Param
    (    
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.FileInfo]
        $Browser
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.FileInfo]
        $Service
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.String]
        $ProfileName
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.IO.DirectoryInfo]
        $ProfilePath
    ,
        [System.Management.Automation.ParameterAttribute()]
        [System.Management.Automation.SwitchParameter]
        $IgnoreCertificateError        
    )

    End
    {
      # $Driver = Start-SeNewEdge -BinaryPath 'C:\Users\artemp\Downloads\edgedriver_win64 — 81.0.416.72\msedgedriver.exe'
      # $Driver = Start-SeNewEdge -WebDriverDirectory $DriverPath -StartURL 'https://onlyfans.com' -Maximized #-ImplicitWait 180

        $ServiceParam = @(

            $Service.Directory.FullName
            $Service.Name
        )
        $ServiceInstance = [OpenQA.Selenium.Edge.EdgeDriverService]::CreateChromiumService.Invoke( $ServiceParam )

        $Options = [OpenQA.Selenium.Edge.EdgeOptions]::new()
        $Options.UseChromium    = $True
        $Options.BinaryLocation = $Browser.FullName

        If
        (
            $ProfileName
        )
        {
            $Options.AddArgument( "profile-directory=$ProfileName" )
        }

        If
        (
            $ProfilePath
        )
        {
          # $Path = Join-Path -Path $Browser.Directory.Parent.FullName -ChildPath 'User Data'
            $Options.AddArgument( "user-data-dir=$($ProfilePath.FullName)" )
        }

        If
        (
            $IgnoreCertificateError
        )
        {
            $Options.AddArgument( 'ignore-certificate-errors' )
        }

     <# Terrible for security. Only use for troubleshooting. Should not
        be needed
        $Options.AddArgument( 'no-sandbox'      )  #>
        $Options.AddArgument( 'start-maximized' )

     <# commandTimeout The maximum amount of time to wait for each command. This is
        a very special timeout that you cannot change after the Driver is starated
      #>
        $DriverTimeOut = [System.TimeSpan]::FromMinutes( 10 )

        $DriverParam = @(

            $ServiceInstance
            $Options
            $DriverTimeOut
        )
        $Driver = [OpenQA.Selenium.Edge.EdgeDriver]::new.Invoke( $DriverParam )

      # $Driver.Manage().Window.Maximize()
    
        $Driver.Manage().Timeouts().AsynchronousJavaScript = [System.TimeSpan]::FromMinutes(  5 )
      # $Driver.Manage().Timeouts().ImplicitWait           = [System.TimeSpan]::FromMinutes(  3 )
      # $Driver.Manage().Timeouts().PageLoad               = [System.TimeSpan]::FromMinutes( 10 )

        Return $Driver
    }
}