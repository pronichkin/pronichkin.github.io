#region Input

    $SourcePah        = 'G:\Old\1903\en_windows_10_business_editions_version_1903_x64_dvd_37200948.iso' 
  # $SourceLabel      = 'CPBA_X64FRE_EN-US_DV9'
  # $TempPath         = Join-Path -Path $env:Temp -ChildPath '1903-PowerShell' 
    $TempPath         = Join-Path -Path $env:Temp -ChildPath ( [System.IO.Path]::GetRandomFileName() )
    $AdkPath          = 'Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment'
  # $DestinationPath = 'c:\1903-PowerShell'  
    $DestinationLabel = 'SpacesPE'  

    $ImageFileName   = 'Boot.wim'
  # $ImageName       = 'Microsoft Windows PE'     # Works for Storage cmdlets
    $ImageName       = 'Microsoft Windows Setup'

  # $Culture = [System.Globalization.CultureInfo]::CurrentCulture

    $PackageName = @(

        'WMI'
        'NetFX'
        'Scripting'
        'PowerShell'
        'StorageWMI'
        'DismCmdlets'
    )

    $Architecture = @{

        9 = 'amd64'
    }

#endregion Input

#region Initialize

    Import-Module -Name @( 'Storage', 'Dism' )

  . 'C:\Users\artemp\OneDrive - Microsoft\Start-ProcessEx.ps1'
  . 'C:\Users\artemp\OneDrive - Microsoft\Start-Dism.ps1'
  . 'C:\Users\artemp\OneDrive - Microsoft\Get-WindowsImageScratchSpace.ps1'
  . 'C:\Users\artemp\OneDrive - Microsoft\Get-WindowsImageTargetPath.ps1'
  . 'C:\Users\artemp\OneDrive - Microsoft\Set-WindowsImageScratchSpace.ps1'
  . 'C:\Users\artemp\OneDrive - Microsoft\Set-WindowsImageTargetPath.ps1'

#endregion Initialize

#region Path

    Write-Debug -Message $TempPath

    If
    (
        Test-Path -Path $TempPath
    )
    {
        $Temp = Get-Item -Path $TempPath
    }
    Else
    {
        $Temp = New-Item -Path $TempPath -ItemType 'Directory'
    }

    $LogName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
    $LogPath = Join-Path -Path $Temp.FullName -ChildPath $LogName
    $Log     = New-Item -Path $LogPath

    $ScratchPath = Join-Path -Path $Temp.FullName -ChildPath 'Scratch'

    If
    (
        Test-Path -Path $ScratchPath
    )
    {
        $Scratch = Get-Item -Path $ScratchPath
    }
    Else
    {
        $Scratch = New-Item -Path $ScratchPath -ItemType 'Directory'
    }

    $MountPath = Join-Path -Path $Temp.FullName -ChildPath 'Mount'

    If
    (
        Test-Path -Path $MountPath
    )
    {
        $Mount = Get-Item -Path $MountPath
    }
    Else
    {
        $Mount = New-Item -Path $MountPath -ItemType 'Directory'
    }

#endregion Path

#region Mount Source

    Write-Verbose -Message 'Mount Source'

    $DiskImage       = Get-DiskImage -ImagePath $SourcePah
    $DiskImage       = Mount-DiskImage -InputObject $DiskImage -Access ReadOnly -PassThru
    $SourceVolume    = Get-Volume -DiskImage $DiskImage
  # $SourceVolume    = Get-Volume -FileSystemLabel $SourceLabel
    $SourceDrive     = Get-psDrive -Name $SourceVolume.DriveLetter
    $SourceImagePath = [System.IO.Path]::Combine( $SourceDrive.Root, 'Sources', $ImageFileName )
    $SourceImage     = Get-Item -Path $SourceImagePath

#endregion Mount Source

#region Export Temp

    $TempImagePath = Join-Path -Path $Temp.FullName -ChildPath $SourceImage.Name

    $ImageParam = @{

        ImagePath = $SourceImage.FullName
        Name      = "$ImageName*"
    }
    $WindowsImageInfo = Get-WindowsImage @ImageParam  # Wim Image Info Object

    Write-Verbose -Message "Export ""$( $WindowsImageInfo.ImageName )"""

    $ImageParam = @{

        SourceImagePath      =  $WindowsImageInfo.ImagePath
        DestinationImagePath =  $TempImagePath
        SourceName           =  $WindowsImageInfo.ImageName
      # DestinationName      =  $ImageName
        Setbootable          =  $True
        CheckIntegrity       =  $True
        CompressionType      = 'None'
        ScratchDirectory     =  $Scratch.FullName
        LogPath              =  $Log.FullName
        LogLevel             = 'WarningsInfo'
    }
    $WindowsImageOffline = Export-WindowsImage @ImageParam  # Offline Image Object

#endregion Export Temp

#region Dismount Source

    Write-Verbose -Message 'Dismount Source'

    $DiskImage = Dismount-DiskImage -InputObject $DiskImage

#endregion Dismount Source

#region Mount Temp

    Write-Verbose -Message "Mount ""$( $WindowsImageInfo.ImageName )"""

    $ImageParam = @{

        Path                 =  $Mount.FullName
        Name                 =  $WindowsImageInfo.ImageName
        ImagePath            =  $WindowsImageOffline.ImagePath
        Optimize             =  $True
        CheckIntegrity       =  $True
        ScratchDirectory     =  $Scratch.FullName
        LogPath              =  $Log.FullName
        LogLevel             = 'WarningsInfo'
    }
    $WindowsImageMount = Mount-WindowsImage @ImageParam  # Image Object
    
#endregion Mount Temp

#region Settings

    Write-Verbose -Message 'Settings'

    $ImageParam = @{

        WindowsImage = $WindowsImageMount
        ScratchSpace =  512mb
        Log          = $Log
        Scratch      = $Scratch
    }
    Set-WindowsImageScratchSpace @ImageParam
    
    $ImageParam = @{

        WindowsImage = $WindowsImageMount
        TargetPath   = 'x:\'  # "Windows" will be added implicitly
        Log          = $Log
        Scratch      = $Scratch
    }
    Set-WindowsImageTargetPath @ImageParam
    
#endregion Settings

#region Add Package

    $Culture = [System.Globalization.CultureInfo]$WindowsImageInfo.Languages[ $WindowsImageInfo.DefaultLanguageIndex ]

    $Package = [System.Collections.Generic.List[Microsoft.Dism.Commands.ImageObject]]::new()

    $PackageName | ForEach-Object -Process {

        @(
            "WinPE-$($psItem).cab"
            "$($Culture.Name)\WinPE-$($psItem)_$($Culture.Name).cab"

        ) | ForEach-Object -Process {

            $PackagePath = [System.IO.Path]::Combine(

                ${env:ProgramFiles(x86)},
                $AdkPath,
                $Architecture[[System.Int32]$WindowsImageInfo.Architecture],
                'WinPE_OCs',
                $psItem
            )

            If
            (
                Test-Path -Path $PackagePath
            )
            {
              # Write-Verbose -Message $PackagePath

                $PackageParam = @{
                
                    Path                 =  $WindowsImageMount.Path
                    PackagePath          =  $PackagePath
                    ScratchDirectory     =  $Scratch.FullName
                    LogPath              =  $LogPath
                    LogLevel             = 'WarningsInfo'
                }
                $Package.Add( $( Add-WindowsPackage @PackageParam ) )
            }
            Else
            {
                Write-Warning -Message "`"$PackagePath`" not found!"
            }
        }
    }

#endregion Add Package

#region Optimize

  # dism /cleanup-image /image:C:\WinPE_amd64\mount\windows /startcomponentcleanup /resetbase /scratchdir:C:\temp
  # DISM /Cleanup-Image /Image="C:\WinPE_amd64\mount" /StartComponentCleanup /ResetBase

#endregion Optimize

#region Dismount Temp

    Write-Verbose -Message "Dismount ""$( $WindowsImageInfo.ImageName )"""

    $ImageParam = @{

        Path                 =  $WindowsImageMount.Path
        Save                 =  $True
        CheckIntegrity       =  $True
        ScratchDirectory     =  $Scratch.FullName
        LogPath              =  $LogPath
        LogLevel             = 'WarningsInfo'
    }
    $WindowsImageBase = Dismount-WindowsImage @ImageParam    

#endregion Dismount Temp

#region Move

    Write-Verbose -Message 'Move'

    $DestinationVolume = Get-Volume -FileSystemLabel $DestinationLabel | Sort-Object -Property 'DriveLetter' | Select-Object -Last 1
    $DestinationDrive  = Get-psDrive -Name $DestinationVolume.DriveLetter
    $DestinationPath   = [System.IO.Path]::Combine( $DestinationDrive.Root, 'Sources' )

    $DestinationImage  = Move-Item -Path $WindowsImageOffline.ImagePath -Destination $DestinationPath -PassThru -Force

#endregion Move

#region Cleanup

    Write-Verbose -Message 'Cleanup'

    Remove-Item -Path $Temp.FullName -Recurse

#endregion Cleanup