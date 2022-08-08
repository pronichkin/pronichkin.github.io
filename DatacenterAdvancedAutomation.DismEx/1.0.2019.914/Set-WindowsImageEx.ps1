#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Function
Set-WindowsImageEx
{
   #region Data

        [cmdletbinding()]

        Param(
            
            [Parameter(
                Mandatory         = $True,
                ValueFromPipeline = $True
            )]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Path          
        ,
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.Xml.XmlDocument]
            $Unattend
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Merge
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.DirectoryInfo]
            $Source
        ,
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [System.String[]]
            $Feature
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.FileSystemInfo[]]
            $Driver
        ,
            [Parameter()]
            [ValidateScript( { Test-Path -Path $psItem.FullName } )]
            [System.Io.FileInfo[]]
            $Package
        ,
            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $RemoteDesktop
        ,
            [Parameter()]
            [System.Management.Automation.SwitchParameter]
            $NoExpandOnNativeBoot
        )

   #endregion Data

   #region Code

       #region Apply Unattend file

            If ( $Unattend )
            {
                $UnattendPath = Join-Path -Path $env:Temp -ChildPath "Unattend.xml"
                $Unattend.Save( $UnattendPath )

                Write-Verbose -Message "Applying unattended answer file"

                $WindowsUnattend = Use-WindowsUnattend -UnattendPath $UnattendPath -Path $Path -Verbose:$False

                $Item = Remove-Item -Path $UnattendPath
            }

       #endregion Apply Unattend file

       #region Merge arbitrary folder

            If ( $Merge )
            {
                Write-Verbose -Message "Applying merge folder ($Merge)"

                $MergeSourcePath = Join-Path -Path $Merge -ChildPath "*"

                $Item = Copy-Item -Path $Merge -Destination $Path -Recurse -Force
            }

       #endregion Merge arbitrary folder

       #region Registry modification

            If ( $RemoteDesktop -or $NoExpandOnNativeBoot ) 
            {
                $HivePath = Join-Path -Path $Path -ChildPath "Windows\System32\Config\System"

                $Hive = Mount-RegistryHive -Hive $HivePath

                If ( $RemoteDesktop )
                {
                    Write-Verbose -Message "Enabling Remote Desktop"

                    Set-ItemProperty -Path "HKLM:\$($Hive)\ControlSet001\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
                }

                If ( $NoExpandOnNativeBoot )
                {
                    Write-Verbose -Message "Disabling automatic Virtual Disk expansion for Native Boot"

                    Set-ItemProperty -Path "HKLM:\$($Hive)\ControlSet001\Services\FsDepends\Parameters" -Name "VirtualDiskExpandOnMount" -Value 4
                }

                $Hive = Dismount-RegistryHive -HiveMountPoint $Hive
            }

       #endregion Registry modification

       #region Offline image management

            If ( $Driver )
            {
                Write-Verbose -Message "Adding Windows Drivers to the Image"

                $Driver | ForEach-Object -Process {

                    Write-Debug -Message "    Driver path: $psItem"
                    
                    $AddWindowsDriverParam = @{

                        Path    = $Path
                        Driver  = $psItem
                        Recurse = $True
                        Verbose = $False
                    }                    
                    $WindowsDriver = Add-WindowsDriver @AddWindowsDriverParam
                }
            }

            If ( $Feature )
            {
                Write-Verbose -Message "Installing Windows Feature(s) $Feature to the Image"

                $EnableWindowsOptionalFeatureParam = @{

                    Path        = $Path
                    FeatureName = $Feature                    
                    All         = $True
                    Verbose     = $False
                }

                If ( $Source )
                {
                    Write-Debug -Message "    From $Source"

                    $EnableWindowsOptionalFeatureParam.Add( "Source", $Source )
                }                
                
                $WindowsOptionalFeature = Enable-WindowsOptionalFeature @EnableWindowsOptionalFeatureParam
            }

            If ( $Package )
            {
                Write-Verbose -Message "Adding Windows Package(s) to the Image"

                $Package | ForEach-Object -Process {

                    Write-Debug -Message "    Package path: $psItem"

                    $AddWindowsPackageParam = @{

                        Path        = $Path
                        PackagePath = $psItem
                        Verbose     = $False
                    }
                    $WindowsPackage = Add-WindowsPackage @AddWindowsPackageParam
                }
            }

       #endregion Offline image management

   #endregion Code

}