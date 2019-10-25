#Requires -RunAsAdministrator
#.ExternalHelp Convert-WindowsImage.xml

Function
Get-WindowsImageEx
{
   #region Data

        [cmdletbinding()]

        Param(
            [parameter(
                Mandatory         = $True,
                ValueFromPipeline = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.IO.FileSystemInfo]
            $Path
        )

   #endregion Data

   #region Code

        $Module = Import-ModuleEx -Name "Dism"

        $WindowsImage = [Microsoft.Dism.Commands.WimImageInfoObject[]]@()

        If ( -Not $Path.psIsContainer )
        {
            $DiskImage = Get-DiskImage   -ImagePath   $Path
            $DiskImage = Mount-DiskImage -InputObject $DiskImage -PassThru
            $DiskImage = Get-DiskImage   -ImagePath   $DiskImage.ImagePath
            $Path      = Get-Item -Path (( Get-Volume    -DiskImage   $DiskImage ).DriveLetter + ":" )
        }

        $WindowsImage = Get-ChildItem -Path $Path -Filter "*.wim" -Recurse | ForEach-Object -Process {

            Get-WindowsImage -ImagePath $PSItem.FullName -Verbose:$False | ForEach-Object -Process {
    
                Get-WindowsImage -Verbose:$False -ImagePath $PSItem.ImagePath -Name $PSItem.ImageName
            }
        }

        If ( Test-Path -Path "Variable:\DiskImage" )
        {
            $DiskImage = Dismount-DiskImage -InputObject $DiskImage -PassThru
        }

        Return $WindowsImage

   #endregion Code
}