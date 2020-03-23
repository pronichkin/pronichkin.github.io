#region Variable

    $ComputerName = 'ArtemP-rs5ja.ntdev.corp.microsoft.com'
    $SourcePath   = '\\winbuilds.ntdev.corp.microsoft.com\release\RS5_RELEASE\17763.1.180914-1434\amd64fre\iso\iso_Server_langpacks\17763.1.180914-1434.rs5_release_SERVERLANGPACKDVD_OEM_MULTI.iso'

    $Language = 'en-us'
    $Region   = 'us'
    $TimeZone = 'Pacific Standard Time'

#endregion Variable

#region Install Language Pack

    $cimSession = New-CimSession -ComputerName $ComputerName -Verbose:$False
    $psSession  = New-psSession  -ComputerName $ComputerName

    $Source = Get-Item -Path $SourcePath
    $Temp   = Join-Path -Path $env:SystemRoot -ChildPath 'Temp'

    Copy-Item -Path $Source.FullName -Destination $Temp -ToSession $psSession

    $ImagePath = Join-Path -Path $Temp -ChildPath $Source.Name

    $DiskImage = Get-DiskImage -CimSession $cimSession -ImagePath $ImagePath

    $DiskImage = Mount-DiskImage -InputObject $DiskImage -Access ReadOnly -NoDriveLetter -PassThru

    $Volume = Get-Volume -DiskImage $DiskImage

    $PackagePath = Join-Path -Path $Volume.Path -ChildPath 'x64\langPacks'

    $PackageFile = Invoke-Command -Session $psSession -ScriptBlock {
        Get-ChildItem -LiteralPath $using:PackagePath -Filter "*$using:Language*"
    }

    $Package = Invoke-Command -Session $psSession -ScriptBlock { 
        Add-WindowsPackage -Online -PackagePath $using:PackageFile.FullName
    }

    [System.Void]( Dismount-DiskImage -InputObject $DiskImage )

    $Command = Invoke-Command -Session $psSession -ScriptBlock {
        Remove-Item -Path $using:ImagePath
    }

#endregion Install Language Pack

#region Per-User settings

    $Culture = [System.Globalization.CultureInfo]::GetCultureInfo( $Language )
    $Region  = [System.Globalization.RegionInfo]::new( $Region )
    
    Invoke-Command -Session $psSession -ScriptBlock {

      # Set-Culture -CultureInfo $using:Culture

        Set-WinHomeLocation -GeoId $using:Region.GeoId

        $Language = New-WinUserLanguageList -Language $using:Language

        Set-WinUserLanguageList -LanguageList $Language -Force
    }

 <# Based on documentation, the following two settings should have followed the
   “Language List” defined above.
 
 1. Culture (aka regional format settings aka user local.) It is supposed to
    follow the “Language List” unless “WinCultureFromLanguageListOptOut” is set.
 
    Note

    Setting Culture explicitly with “Set-Culture” has some mixed effect. The
    configuration seems to stick to session *type*. I.e. setting it for a
    remote PowerShell session will apply to all remote PowerShell sessions,
    including new ones opened after machine restart. However, it won't apply
    to interactive desktop sessions, such as local or over RDP. In these
    sessions, both “Get-Culture” and Intl.cpl will display the old Culture.
    
 2. Windows user interface language. It is also supposed to dynamically follow 
    the “Language List” unless “WinUILanguageOverride” is set.

    Apparently, neiver of the above is happening, and these settings are stick
    forever to their original values. (Both per the observed actual behavior,
    as well as reported by Intl.cpl.)

    To overcome the inconsistencies, below is an alternative method to 
    explicitly define these settings.
    
    (https://support.microsoft.com/help/2764405)
  #>

    $xml = @"
<?xml version="1.0" encoding="utf-8"?>

<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">

    <gs:UserList>
        <gs:User
            UserID="Current"
        />
    </gs:UserList>

    <gs:MUILanguagePreferences>
        <gs:MUILanguage
            Value="$Language"
        />
    </gs:MUILanguagePreferences>

    <gs:UserLocale>
        <gs:Locale
            Name="$Language"
            SetAsCurrent="true"
            ResetAllSettings="true"
        />
    </gs:UserLocale>

</gs:GlobalizationServices>
"@

    $xmlPath     = Join-Path -Path $env:SystemRoot -ChildPath 'Temp\Globalization.xml'
    $ControlPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Control.exe'
    $Argument    = "Intl.cpl,,/f:""$xmlPath"""

    Invoke-Command -Session $psSession -ScriptBlock {

        $xml = [System.Xml.XmlDocument]::new()
        $xml.LoadXml( $using:xml )
        $xml.Save( $using:xmlPath )

        Start-Process -FilePath $using:ControlPath -ArgumentList $using:Argument -Wait

        Remove-Item -Path $using:xmlPath
    }

 <# At this point, the user interface langage for current user is supposed
    to have been changed. Validating with “Get-WinUserLanguageList” (or
   “intl.cpl” in RDP) will tell you that the current language is set to the
    desired value.
    
    However, that does not seem to be the case. User interface is still 
    localized to the original language. This includes the language of 
    output for commands (e.g. DISM banner says “Tool zur Imageverwaltung fr
    die Bereitstellung” in German instead of “Deployment Image Servicing and
    Management tool”) and values (e.g. diplay name for “English (United States)”
    is “Englisch (Vereinigte Staaten)”.)

    This wil be fixed when you continue to the next step and change the System
    display language. At this point, it's safe to proceed, even though the
    current state is not quite as expected.

    Terminating the session and restarting it is supposed to pick up the new
    settings, but as per above it does not help much. (Neither does a full
    reboot.)
  #>

    $psSession = Disconnect-psSession -Session $psSession
    
    Remove-PSSession -Session $psSession
    
    $psSession  = New-psSession  -ComputerName $ComputerName

#endregion per-User settings

#region System-wide settings

    $Command = Invoke-Command -Session $psSession -ScriptBlock {

        Set-TimeZone -Id $using:TimeZone

        Set-WinSystemLocale -SystemLocale $using:Culture
    }

 <# Apparently, Intl.cpl XML-driven automation is the only supported way
    to define settings for the System and for Default user accounts
    https://support.microsoft.com/help/2764405
  #>

    $xml = @'
<?xml version="1.0" encoding="utf-8"?>

<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">

    <gs:UserList>
        <gs:User
            CopySettingsToDefaultUserAcct="true"
            CopySettingsToSystemAcct="true"
            UserID="Current"
        />
    </gs:UserList>

</gs:GlobalizationServices>
'@

    $xmlPath     = Join-Path -Path $env:SystemRoot -ChildPath 'Temp\Globalization.xml'
    $ControlPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Control.exe'
    $Argument    = "Intl.cpl,,/f:""$xmlPath"""

    Invoke-Command -Session $psSession -ScriptBlock {

        $xml = [System.Xml.XmlDocument]::new()
        $xml.LoadXml( $using:xml )
        $xml.Save( $using:xmlPath )

        Start-Process -FilePath $using:ControlPath -ArgumentList $using:Argument -Wait

        Remove-Item -Path $using:xmlPath
    }

    Restart-Computer -ComputerName $ComputerName -Wait -Protocol 'wsMan' -Force

 <# At this point, the user interface (including command line output) is
    diplayed in the desired language. Stop here if you only intend to use
    supported mechanisms
  #>

    $psSession  = New-psSession  -ComputerName $ComputerName

#endregion System-wide settings

#region Default System UI Language

 <# This is the original installation language. Changing it would allow to
    uninstall the language package completely. Which is probably unsupported
  #>

  # Convert the LCID to hex and pad with a zero

    $InstallLanguage = ( [System.Int32]$Culture.LCID.ToString( "x" ) ).ToString( "d4" )

    Invoke-Command -Session $psSession -ScriptBlock {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Nls\Language' -Name 'InstallLanguage' -Value $using:InstallLanguage
    }

    Restart-Computer -ComputerName $ComputerName -Wait -Protocol 'wsMan' -Force

    $psSession  = New-psSession  -ComputerName $ComputerName

#endregion Default System UI Language

#region Uninstall Language Pack

    $Package = Invoke-Command -Session $psSession -ScriptBlock {

        Get-WindowsPackage -Online | Where-Object -FilterScript {
            $psItem.ReleaseType -eq [Microsoft.Dism.Commands.ReleaseType]::LanguagePack -And
            $psItem.PackageName -notLike "*$using:Language*"
        }
    }

    $Package = Invoke-Command -Session $psSession -ScriptBlock {
        Remove-WindowsPackage -Online -PackageName $using:Package.PackageName -NoRestart
    }

#endregion Uninstall Language Pack