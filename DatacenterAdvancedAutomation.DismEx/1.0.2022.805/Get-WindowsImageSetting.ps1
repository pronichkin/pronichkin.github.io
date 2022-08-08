    Import-Module -Name @( 'Storage', 'Dism' )

  . 'C:\Users\artemp\OneDrive - Microsoft\Start-ProcessEx.ps1'
  . 'C:\Users\artemp\OneDrive - Microsoft\Start-Dism.ps1'

    $TempPath         = Join-Path -Path $env:Temp -ChildPath ( [System.IO.Path]::GetRandomFileName() )


    $i = Copy-Item -Path 'C:\Users\artemp\Downloads\SpacesBootSetup\WinPE\boot.wim' -Destination $Temp.FullName -PassThru

    $WindowsImageInfo = Get-WindowsImage -ImagePath $i.FullName

    $WindowsImageOffline = Get-WindowsImage -ImagePath $WindowsImageInfo.ImagePath -Name $WindowsImageInfo.ImageName
