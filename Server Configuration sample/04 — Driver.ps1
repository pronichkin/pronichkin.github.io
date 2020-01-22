$Name = 'TBT_WIN10_64_DCH_58'

$psSession | ForEach-Object -Process {

    Copy-Item -Path ".\Downloads\$Name.zip" -ToSession $psItem -Destination ( Join-Path -Path $env:SystemRoot -ChildPath 'Temp' )
}

Invoke-Command -Session $psSession -ScriptBlock {

    Set-Location -Path ( Join-Path -Path $env:SystemRoot -ChildPath 'Temp' )

    Expand-Archive -Path ".\$($using:Name).zip"

    pnputil.exe /Add-Driver ".\$($using:Name)\*.inf" /Install
}