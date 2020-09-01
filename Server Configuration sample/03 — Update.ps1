<#

    First we need to ensure that either “Windows Update Provider” module is 
    available (i.e. the target machine runs pre-Vb OS), or the custom PowerShell
    session configuration is already registered. If neither condition is true, 
    we need to register session configuration

#>

$Message = 'Validating prerequisite(s)'
Write-Message -Channel Verbose -Message $Message

$Service = Invoke-Command -Session $psSession -ScriptBlock {

    $ErrorActionPreference = $Using:ErrorActionPreference
    $VerbosePreference     = $Using:VerbosePreference
    $DebugPreference       = $Using:DebugPreference    

    $Module = Get-Module -Name 'WindowsUpdateProvider' -ListAvailable

    If
    (
        $Module
    )
    {
        Import-Module -ModuleInfo $Module -Verbose:$False

        [System.Tuple[System.Boolean]]$False
    }
    Else
    {
        $Message = "Windows Update WMI provider is not available on $($env:ComputerName), will fail back to COM object"
      # Write-Message -Channel Debug -Message $Message
        Write-Debug -Message $Message

        $SessionConfiguration = Get-psSessionConfiguration -Verbose:$False | Where-Object -FilterScript {
            $psItem.Name -eq 'VirtualUpdate'
        }

        If
        (
            $SessionConfiguration
        )
        {
            $Message = "Session configuration is already registered on $($env:ComputerName)"
            Write-Debug -Message $Message

            [System.Tuple[System.Boolean]]$False
        }
        Else
        {
            $Message = "Registering session configuration on $($env:ComputerName)"
            Write-Debug -Message $Message


            $Path = '.\VirtualUpdate.pssc'

            New-psSessionConfigurationFile -RunAsVirtualAccount -Path $Path

         <# Apparently, “Register-psSessionConfiguration” ignores “-Verbose” and 
            “WarningAction” parameters and always emits output. Hence, we need 
            to temporarily change the preferences and restore them after the
            command is ran  #>

            $VerbosePreferenceState = $VerbosePreference
            $VerbosePreference      = [System.Management.Automation.ActionPreference]::SilentlyContinue

            $WarningPreferenceState = $WarningPreference
            $WarningPreference      = [System.Management.Automation.ActionPreference]::SilentlyContinue

         <# Cannot restart the WinRM service just yet because this will break the
            very session we're operating in  #>

            $SessionConfigurationParam = @{
                
                Name             = 'VirtualUpdate'
                Path             = $Path
                NoServiceRestart = $True
                Verbose          = $False
                WarningAction    = [System.Management.Automation.ActionPreference]::SilentlyContinue
            }
            $SessionConfiguration = Register-psSessionConfiguration @SessionConfigurationParam

            $VerbosePreference = $VerbosePreferenceState
            $WarningPreference = $WarningPreferenceState

            Remove-Item -Path $Path

            [System.Tuple[System.Boolean]]$True
        }
    }
}

$Message = 'Restarting WinRM service if needed'
Write-Message -Channel Verbose -Message $Message

$Service | Where-Object -FilterScript { $psItem.Item1 } | ForEach-Object -Process {

    $AddressCurrent = $psItem.psComputerName

    $SessionParam = @{

        ComputerName = $AddressCurrent
        Verbose      = $False
    }

 <# Cannot use “Get-Service” here because it won't allow to specify explicit
    credentials for an untrusted computer  #>

    $ServiceParam = @{ 
    
        ComputerName = $AddressCurrent
        Name         = 'WinRM'
    }

    If
    (
        Test-Path -Path 'Variable:\Credential'
    )
    {
        $ServiceParam.Add(
            'Credential',
            $Credential
        )

        $SessionParam.Add(
            'Credential',
            $Credential
        )
    }

    $Message = "Restarting WinRM service on `“$AddressCurrent`”"
    Write-Message -Channel Debug -Message $Message

    $Service = Get-ServiceEx @ServiceParam
    Restart-Service -InputObject $Service

 <# Existing sessions are invalidated once service is restarted. Hence need to
    establish new ones. Moreover, we cannot remove an object from collection,
    hence need to create new ones. Finally, we cannot simply filter the existing
    collection, exclude the broken session and assign the result to the same
    variable right away. The reason is that if it's the only session in the
    collection, an empty collection won't be of expected type, and will be 
   “$Null” instead. Hence we need to explicitly define the collection as a new
    object  #>

  # These may be null

    [System.Collections.Generic.List[
        System.Management.Automation.Runspaces.psSession
    ]]$psSessionCurrent  = $psSession | Where-Object -FilterScript {
        $psItem.ComputerName -ne $AddressCurrent
    }

    [System.Collections.Generic.List[
        Microsoft.Management.Infrastructure.CimSession
    ]]$cimSessionCurrent = $cimSession | Where-Object -FilterScript {
        $psItem.ComputerName -ne $AddressCurrent
    }

  # These are the new collections

    $psSession  = [System.Collections.Generic.List[
        System.Management.Automation.Runspaces.psSession
    ]]::new()

    $cimSession = [System.Collections.Generic.List[
        Microsoft.Management.Infrastructure.CimSession
    ]]::new()

    If
    (
        $psSessionCurrent
    )    
    {
        $psSession.AddRange(  $psSessionCurrent  )
    }

    If
    (
        $cimSessionCurrent
    )
    {
        $cimSession.AddRange( $cimSessionCurrent )
    }

    $psSession.Add(  ( New-psSession  @SessionParam ) )
    $cimSession.Add( ( New-cimSession @SessionParam ) )
}

$Message = 'Scanning and installing updates'
Write-Message -Channel Verbose -Message $Message

$Install = Invoke-Command -Session $psSession -ScriptBlock {

    $ErrorActionPreference = $Using:ErrorActionPreference
    $VerbosePreference     = $Using:VerbosePreference
    $DebugPreference       = $Using:DebugPreference    

    $Module = Get-Module -Name 'WindowsUpdateProvider' -ListAvailable

    If
    (
        $Module
    )
    {
      # “Import-Module” will emit verbose output even despite “-Verbose:$False”
        $VerbosePreference     = [System.Management.Automation.ActionPreference]::SilentlyContinue

        Import-Module -ModuleInfo $Module -Verbose:$False

        $VerbosePreference     = $Using:VerbosePreference

      # Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    Scanning $($env:ComputerName)"

        $Message = "Scanning $($env:ComputerName) using Windows Update WMI provider"
    }
    Else
    {
        $Message = "Scanning $($env:ComputerName) using Windows Update COM object"

     <# We'll have to use the “Microsoft.Update.Session” COM object. Unfortunately,
        when using it in a remote session, most operations will fail with
       “0x80070005” (generic access denied error.) This is by design, as per
        https://docs.microsoft.com/windows/win32/wua_sdk/using-wua-from-a-remote-computer
        To work around this limitation, we need to use a specially crafted
        PowerShell session which is using a virtual account and hence does not
        count as remote  #>

        $psSessionCurrent = New-PSSession -ConfigurationName 'VirtualUpdate' -EnableNetworkAccess

        Invoke-Command -Session $psSessionCurrent -ScriptBlock {
            
            $Session    = New-Object -ComObject 'Microsoft.Update.Session'

            $Searcher   = $Session.CreateUpdateSearcher()
          # $Query      = 'IsInstalled = 0 and DeploymentAction = ''OptionalInstallation'''
          # $Query      = 'IsInstalled = 0'

            $Query      = [System.String]::Empty
            $Query     += "IsInstalled=0 and DeploymentAction='Installation' or "
            $Query     += "IsInstalled=0 and DeploymentAction='OptionalInstallation' or "
            $Query     += "IsPresent=1 and DeploymentAction='Uninstallation' or "
            $Query     += "IsInstalled=1 and DeploymentAction='Installation' and RebootRequired=1 or "
            $Query     += "IsInstalled=0 and DeploymentAction='Uninstallation' and RebootRequired=1"
        }
    }

  # Write-Message -Channel Debug -Message $Message
    Write-Debug -Message $Message

    If
    (
        $Module
    )
    {
        $Update = Start-wuScan -Verbose:$False
    }
    Else
    {
        $Update = Invoke-Command -Session $psSessionCurrent -ScriptBlock {
            
            $Update = ( $Searcher.Search( $Query ) ).Updates

            Return $Update
        }
    }

    If
    (
        $Module -and $Update -or
        $Update.Count
    )
    {
      # Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    Updates found on $($env:ComputerName)"

        $Message = "Updates found on $($env:ComputerName)"
      # Write-Message -Channel Debug -Message $Message
        Write-Debug -Message $Message

        $Update | Sort-Object -Property 'Title' | ForEach-Object -Process {
          # Write-Debug -Message "    * $( $psItem.Title )"

            $Message = "  * $( $psItem.Title )"
          # Write-Message -Channel Debug -Message $Message -Indent 1
            Write-Debug -Message $Message
        }

      # Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    Installing on $($env:ComputerName)"

        $Message = "Installing on $($env:ComputerName)"
      # Write-Message -Channel Debug -Message $Message
        Write-Debug -Message $Message

        If
        (
            $Module
        )
        {
            $Reboot     = Install-wuUpdates -Updates $Update -Verbose:$False
        }
        Else
        {
            $Download   = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

                $Downloader = $Session.CreateUpdateDownloader() 
                $Downloader.Updates = $Update
                $Downloader.Download()
            }

            If
            (
                $Download.HResult
            )
            {
                $Message = "Download failed with Result Code $($Download.ResultCode), HResult $($Download.HResult)"

                Write-Warning -Message $Message

                $Reboot = $False
            }
            Else
            {
                $Install    = Invoke-Command -Session $psSessionCurrent -ScriptBlock {

                    $Installer  = $Session.CreateUpdateInstaller()
                    $Installer.Updates = $Update
                    $Installer.Install()
                }

                If
                (
                    $Install.HResult
                )
                {
                    $Message = "Installation failed with Result Code $($Install.ResultCode), HResult $($Install.HResult)"

                    Write-Warning -Message $Message

                    $Reboot = $False
                }
                Else
                {
                    $Reboot     = $Install.RebootRequired
                }
            }
        }

        [System.Tuple[System.Boolean]]$Reboot
    }
    Else
    {
      # Write-Verbose -Message "$((Get-Date).ToUniversalTime().ToLongTimeString())    No updates found on $($env:ComputerName)"

        $Message = "No updates found on $($env:ComputerName)"
      # Write-Message -Channel Debug -Message $Message
        Write-Debug -Message $Message

        [System.Tuple[System.Boolean]]$False
    }
}

$Restart = $Install | Where-Object -FilterScript { $psItem.Item1 }

If
(
    $Restart
)
{
  # Write-Verbose -Message 'Restarting'

    $Message = 'Restarting'
    Write-Message -Channel Verbose -Message $Message

    $Restart.psComputerName | ForEach-Object -Process {
    
        $Message = "* $psItem"
      # Write-Verbose -Message $Message
        Write-Message -Channel Debug -Message $Message -Indent 1
    }

 <# -Protocol 'dcom' (which is the default) fails with:
    
   “Fail to retrieve its LastBootUpTime via the WMI service with the following 
    error message: Call was canceled by the message filter.
    (Exception from HRESULT: 0x80010002 (RPC_E_CALL_CANCELED))”
    
    in case computer was never restarted yet

    Additionally, without “-Force” it fails with “The parameter is incorrect.”
  #>

    $ComputerParam = @{
    
        ComputerName = $Restart.psComputerName        
        Protocol     = 'wsMan'
        Wait         = $True
        Force        = $True
    }

    If
    (
        Test-Path -Path 'variable:\Credential'
    )
    {
        $ComputerParam.Add(
            'wsmanAuthentication', 'Negotiate'
        )
        
        $ComputerParam.Add(
            'Credential',          $Credential
        )
    }

    Restart-Computer @ComputerParam
}
Else
{
    $Message = 'No computers required reboot'

    Write-Message -Channel Verbose -Message $Message
}