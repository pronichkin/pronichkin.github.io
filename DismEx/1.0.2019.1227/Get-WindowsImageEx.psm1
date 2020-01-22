#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Set-StrictMode -Version 'Latest'

Function
Get-WindowsImageEx
{
    [cmdletBinding(
        DefaultParametersetName = 'Online'
    )]

  # [outputType([Microsoft.Win32.RegistryKey])]

    Param(
        [Parameter(
            Mandatory        = $False,
            ParameterSetName = 'Online'
        )]
        [System.String]
        [ValidateNotNullOrEmpty()]
        $ComputerName = $env:ComputerName
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Offline'
        )]
      # [System.IO.FileInfo]
      # [System.IO.DirectoryInfo]
        [System.IO.FileSystemInfo]
        $Path
    )

    Begin
    {
        [System.Void]( Import-ModuleEx -Name @( 'Storage', 'Dism' ) )
    }

    Process
    {
        If
        (
           -Not $path -Or
            $path.psIsContainer
        )
        {
            $RegistryKeyParam = @{
                Name = 'Software\Microsoft\Windows NT\CurrentVersion'
            }

            If
            (
                $Path
            )
            {
                $RegistryKeyParam.Add( 'Path', $Path )
            }
            Else
            {
                $RegistryKeyParam.Add( 'ComputerName', $ComputerName )
            }

            [Microsoft.Win32.RegistryKey]$Return = Get-RegistryKey @RegistryKeyParam
        }
        ElseIf
        (
            Test-Path -Path $Path.FullName
        )
        {
            $Return = [System.Collections.Generic.Dictionary[
                System.Collections.Generic.Dictionary[
                    System.String, System.String
                ],
                Microsoft.Win32.RegistryKey
            ]]::new()

            Switch
            (
                $Path.Extension
            )
            {
                '.iso'
                {
                   #region Mount image

                    $DiskImage = Get-DiskImage -ImagePath $Path.FullName

                    If
                    (
                        $DiskImage.Attached
                    )
                    {
                        $Message = 'The image is already attached'
                    }
                    Else
                    {
                        $DiskImageParam = @{
                    
                            InputObject   = $DiskImage
                            PassThru      = $True
                            Access        = 'ReadOnly'
                            NoDriveLetter = $True
                        }
                        $DiskImage = Mount-DiskImage @DiskImageParam

                        $Message = 'Attaching image'
                    }

                    Write-Debug -Message $Message

                   #endregion Mount image

                   #region Loop through image files

                    $Volume = Get-Volume -DiskImage $DiskImage
                    $Source = Join-Path -Path $Volume.Path -ChildPath 'Sources'

                    If
                    (
                        Test-Path -Path $Source
                    )
                    {
                        Get-ChildItem -Path $Source -Include '*.wim' | ForEach-Object -Process {
                
                            ( Get-WindowsImageEx -Path $psItem ).GetEnumerator() | ForEach-Object -Process {

                                $Return.Add( $psItem.Key, $psItem.Value )
                            }
                        }
                    }
                    Else
                    {
                        $Message = 'The specified Disk Image is not a Windows installation media'

                        Write-Warning -Message $Message
                    }

                   #endregion Loop through image files

                   #region Dismount image

                    $DiskImage = Dismount-DiskImage -InputObject $DiskImage

                   #endregion Dismount image
                }

                '.wim'
                {
                   #region Obtain the list of images inside the image file

                 <# Both DISM PowerShell (“Get-WindowsImage”) *and* modern
                    DISM.exe syntax (“/Get-ImageInfo”) fail to obtain image
                    information when using global (GUID-based) volume paths,
                    e.g. when there's no drive letter
                  #>

                    $Argument = [System.Collections.Generic.List[System.String]]::new()
                    $Argument.Add( '/Get-WimInfo'                   )
                    $Argument.Add( "/WimFile=""$($Path.FullName)""" )

                    $Dism = Start-Dism -Argument $Argument

                   #endregion Obtain the list of images inside the image file

                   #region Loop through all the images inside the image file

                    $Dism.Where( { $psItem -like 'Name : *' } ) | ForEach-Object -Process {              
                        
                       #region Detailed information (metadata) about the image

                        $Name = $psItem.Replace( 'Name : ', [System.String]::Empty )

                     <# Note
                        This is intended to be reasonably close to the
                       “Microsoft.Dism.Commands.ImageInfoObject” type produced
                        by native DISM PowerShell
                      #>

                        $ImageMeta = [System.Collections.Generic.Dictionary[
                            System.String, System.String
                        ]]::new()

                        $Argument = [System.Collections.Generic.List[System.String]]::new()
                        $Argument.Add( '/Get-WimInfo'                   )
                        $Argument.Add( "/WimFile=""$($Path.FullName)""" )
                        $Argument.Add( "/Name=""$Name"""                )

                        $Dism = Start-Dism -Argument $Argument

                        $Dism | Where-Object -FilterScript {
                            $psItem -like '* : *'
                        } | ForEach-Object -Process {
                    
                            $Split = $psItem -split ' : '

                            $ImageMeta.Add( $Split[0], $Split[1] )
                        }
                 
                        $LanguageStart = $Dism.IndexOf( 'Languages :' ) + 1
                        $LanguageEnd   = $Dism.IndexOf( 'The operation completed successfully.' ) - 2
                        $Language      = $LanguageStart..$LanguageEnd | ForEach-Object -Process {
                            $Dism[ $psItem ].Trim()
                        }                        

                        $ImageMeta.Add(
                            'Languages',
                            $Language -join [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ListSeparator
                        )

                       #endregion Detailed information (metadata) about the image

                       #region Mount image and obtain actual Windows information

                        $ImageParam = @{

                            ImagePath = $Path
                            Name      = $Name
                            ReadOnly  = $True
                        }
                        $Path = Mount-WindowsImageEx @ImageParam

                        $Image = Get-WindowsImageEx -Path $Path
                
                        $ImageParam = @{

                            Path    = $Path
                            Action  = 'Discard'
                            Cleanup = $True
                        }
                        $Path = Dismount-WindowsImageEx @ImageParam

                       #endregion Mount image and obtain actual Windows information

                        $Return.Add( $ImageMeta, $Image )
                    }

                   #endregion Loop through all the images inside the image file
                }

                Default
                {
                    $Message = "Unexpected Image file extension `“$($Path.Extension)`”"
                    Write-Warning -Message $Message
                }
            }
        }
        Else
        {
            $Message = 'Unexpected input'
            
            Write-Warning -Message $Message
        }
    }

    End
    {
        Return $Return
    }
}