using module '.\Architecture.psm1'

Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Add stuff to a Windows Image and configure its settings
#>

function
Set-WindowsImage
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [Microsoft.Dism.Commands.BaseDismObject]
    )]

    param
    (    
        [System.Management.Automation.AliasAttribute(
            'Image'
        )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
     <# this is a basic object returned by `Get-WindowsImage` without specifying
       `-Name` or `-Index`. There can be multiple images inside the same image
        file (wim) and hence this type does not suite the purpose of this script.
      #>
      # [Microsoft.Dism.Commands.ImageObject]
     <# this is the detailed object returned by `Get-WidnowsImage` when
        either `-Name` or `-Index` is specified. This is a fully qualified
        image object and it suites the purpose of this script.
      #>
        [Microsoft.Dism.Commands.WimImageInfoObject]
      # Image to alter
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Temporary location for Mount, Log and Scratch directories
        $Path = ( New-TemporaryDirectory )
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.IO.DirectoryInfo]
      # Location for package sources
        $Source = (
            ( Get-WindowsDeploymentAndImagingToolsEnvironment )[ 'WinPERoot' ]
        )
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.Collections.Generic.List[
            System.String
        ]]
      # Name(s) of the Package(s) to add
        $PackageNameAdd
    )

    begin
    {
       #region    Script temp path

            $mount   = Get-ItemEx -Path $Path -Name 'Mount'   -Directory
            $scratch = Get-ItemEx -Path $Path -Name 'Scratch' -Directory
            $log     = Get-ItemEx -Path $Path -Name 'Log'     -Directory

       #endregion Script temp path

       #region    Package to add

            $packageAdd = [System.Collections.Generic.List[
                System.IO.FileInfo
            ]]::new()
        
            $PackageNameAdd | ForEach-Object -Process {

                if
                (
                    Test-Path -Path $psItem
                )
                {
                  # This is an actual file

                    $packageAdd.Add(
                        ( Get-Item -Path $psItem )
                    )
                }
                else
                {
                  # This should be a WinPE feature package
                    
                    $packageAddBaseName = "WinPE-$psItem"

                  # Generate file name(s) for the feature package itself
                  # and its dependent localization packages

                    $packageAddFileName = [System.Collections.Generic.List[
                        System.String
                    ]]::new()

                    $packageAddFileName.Add( "$packageAddBaseName.cab" )

                    $InputObject.Languages | ForEach-Object -Process {

                        $packageAddLanguageName = [system.io.path]::Combine(
                            $psItem,
                            "$($packageAddBaseName)_$psItem"
                        )

                        $packageAddFileName.Add( "$packageAddLanguageName.cab" )
                    }

                  # Generate full paths for the package names and select
                  # ones that exist

                    $packageAdd.AddRange(
                        [System.Collections.Generic.List[
                            System.IO.FileInfo
                        ]](                            
                            $packageAddFileName | ForEach-Object -Process {
                                [System.IO.FileInfo][System.IO.Path]::Combine(
                                    $source.FullName,
                                    [Architecture]$InputObject.Architecture,
                                    'WinPE_OCs',
                                    $psItem
                                )
                            } | Where-Object -FilterScript { $psItem.Exists }
                        )
                    )
                }
            }

       #endregion Package to add




    }

    process
    {
   #region    Mount

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Mount: $logPath"

        $imageParam = @{
            ImagePath             = $image.FullName
            Name                  = $sourceName
            CheckIntegrity        = $true
            Path                  = $mount.FullName
            ScratchDirectory      = $scratchPath
            LogPath               = $logPath
            LogLevel              = [Microsoft.Dism.Commands.LogLevel]::Debug
            Verbose               = $false
        }
      # Microsoft.Dism.Commands.ImageObject
        $Image = Mount-WindowsImage @imageParam

   #endregion Mount

   #region    Package

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Package: $logPath"

      # Microsoft.Dism.Commands.ImageObject
        $package = $packagePath | ForEach-Object -Process {
            Write-Verbose -Message "  * $psItem"
            $packageParam = @{
                PackagePath      = $psItem
                Path             = $image.Path
                ScratchDirectory = $scratchPath
                LogPath          = $logPath
                LogLevel         = [Microsoft.Dism.Commands.LogLevel]::Debug
                Verbose          = $false
            }
            Add-WindowsPackage @packageparam
        }

   #endregion Package

   #region    Update

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Update: $logPath"

      # Microsoft.Dism.Commands.ImageObject
        $update = $updatePath | ForEach-Object -Process {
            Write-Verbose -Message "  * $psItem"
            $packageParam = @{
                PackagePath      = $psItem
                Path             = $image.Path
                ScratchDirectory = $scratchPath
                LogPath          = $logPath
                LogLevel         = [Microsoft.Dism.Commands.LogLevel]::Debug
                Verbose          = $false
            }
            Add-WindowsPackage @packageparam
        }

   #endregion Update

   #region    Driver

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Driver: $logPath"

        $driverParam = @{
            Driver           = $driverPath
            Recurse          = $true
            Path             = $image.Path
            ScratchDirectory = $scratchPath
            LogPath          = $logPath
            LogLevel         = [Microsoft.Dism.Commands.LogLevel]::Debug
            Verbose          = $false
        }
      # Microsoft.Dism.Commands.BasicDriverObject
        $driver = Add-WindowsDriver @driverParam

   #endregion Driver

   #region    Setting

      # Dism.exe /image:$($image.Path) /Get-peSettings
      # Dism.exe /image:$($image.Path) /Get-ScratchSpace
      # Dism.exe /image:$($image.Path) /Get-TargetPath

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Setting: $logPath"

        Dism.exe /image:$($image.Path) /Set-ScratchSpace:512 /ScratchDir:$scratchPath /LogPath:$logPath /LogLevel:4

   #endregion Setting

   #region    Cleanup and reset

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Cleanup and reset: $logPath"

        $imageParam = @{
          # ScanHealth            = $true  # doews not work with WinPE
            StartComponentCleanup = $true
            ResetBase             = $true
            Path                  = $image.Path
            ScratchDirectory      = $scratchPath
            LogPath               = $logPath
            LogLevel              = [Microsoft.Dism.Commands.LogLevel]::Debug
            Verbose               = $false
        }
      # Microsoft.Dism.Commands.ImageObjectWithState
        $image = Repair-WindowsImage @imageParam

   #endregion Cleanup and reset

   #region    Dismount

        $logName = ( Get-Date -Format 'FileDateTimeUniversal' ) + '.log'
        $logPath = Join-Path -Path $log.FullName -ChildPath $logName

        Write-Verbose -Message "Dismount: $logPath"

        $imageParam = @{
            Save                  = $true
          # Discard               = $true
            CheckIntegrity        = $true
            Path                  = $image.Path
            ScratchDirectory      = $scratchPath
            LogPath               = $logPath
            LogLevel              = [Microsoft.Dism.Commands.LogLevel]::Debug
            Verbose               = $false
        }
      # Microsoft.Dism.Commands.BaseDismObject
        $image = Dismount-WindowsImage @imageParam

   #endregion Dismount
    }

    end
    {
    }
}