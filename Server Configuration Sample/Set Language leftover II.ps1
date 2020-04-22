  # This will be needed to restart computer remotely

    Get-NetFirewallRule -CimSession $cimSession -Name 'WMI-*-In-TCP' | Enable-NetFirewallRule
    Get-NetFirewallRule -CimSession $cimSession -Name 'RemoteEventLogSvc-*In-TCP' | Enable-NetFirewallRule



 
    $psSession = Get-psSession -ComputerName $ComputerName | Where-Object -FilterScript {
        $psItem.State -eq [System.Management.Automation.Runspaces.RunspaceState]::Opened
    }
    

 <# The Culture setting (aka “regional format” aka user locale) seems to be
    specific to *session type*. Above you have changed it for remote PowerShell
    sessions. Subsequent remote PowerShell sessions will stick to it. However,
    if you open an RDP session it will have the old Culture. You will have to
    change it there, too (by running “Set-Culture” or “intl.cpl”.)  #>


    Restart-Computer -ComputerName $ComputerName -Wait -Protocol 'wsMan' -Force

    $cimSession = New-CimSession -ComputerName $ComputerName -Verbose:$False
    $psSession  = New-psSession  -ComputerName $ComputerName

  # The last command is supposed to have changed the display language but
  # apparently it does not. The following is another method for that same
  # but it works
  # https://support.microsoft.com/help/2764405  

    $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
    <!--User List-->
    <gs:UserList>
        <gs:User UserID="Current" />
    </gs:UserList>



</gs:GlobalizationServices>
'@

    $xmlPath = Join-Path -Path $env:SystemRoot -ChildPath 'Temp\Language.xml'

    $Path = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Control.exe'
 
    $Argument = "Intl.cpl,,/f:""$xmlPath"""

    Invoke-Command -Session $psSession -ScriptBlock {

        $xmlDocument = [System.Xml.XmlDocument]::new()
        $xmlDocument.LoadXml( $using:xml )
        $xmlDocument.Save( $using:xmlPath )

        Start-Process -FilePath $using:Path -ArgumentList $using:Argument -Wait

        Remove-Item -Path $using:xmlPath
    }



    #region Workaround for changing the Culture

  # The following apparently does not take effect at all when you run it remotely
  # in a PowerShell session. Go to RDP and run it there.

    $Language = 'en-us'
    $Culture = [System.Globalization.CultureInfo]::GetCultureInfo( $Language )
    Set-Culture -CultureInfo $Culture
    logoff.exe

#endregion Workaround for changing the Culture