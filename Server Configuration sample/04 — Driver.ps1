  # $Name = 'TBT_WIN10_64_DCH_58'
    $Name = 'Thunderbolt_Win10_Version-66'

$psSession | ForEach-Object -Process {

    Copy-Item -Path "$($env:UserProfile)\Downloads\$Name.zip" -ToSession $psItem -Destination ( Join-Path -Path $env:SystemRoot -ChildPath 'Temp' ) -Force
}

Invoke-Command -Session $psSession -ScriptBlock {

    Set-Location -Path ( Join-Path -Path $env:SystemRoot -ChildPath 'Temp' )

    Expand-Archive -Path ".\$($using:Name).zip" -Force

    pnputil.exe /Add-Driver ".\$($using:Name)\*.inf" /Install
}