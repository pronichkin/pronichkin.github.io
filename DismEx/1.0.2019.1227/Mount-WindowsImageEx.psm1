Set-StrictMode -Version 'Latest'

Function
Mount-WindowsImageEx
{
    [cmdletBinding()]

    [outputType([System.IO.DirectoryInfo])]

    Param(

        [Parameter(
            Mandatory        = $False
        )]
        [System.IO.DirectoryInfo]
        $Path
    ,
        [Parameter(
            Mandatory        = $True
        )]
        [System.IO.FileInfo]
        $ImagePath
    ,
        [Parameter(
            Mandatory        = $True
        )]
        [System.String]
        $Name
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $ReadOnly
    )

    Begin
    {
        If
        (
            $Path
        )
        {
            If
            (
                Test-Path -Path $Path.FullName
            )
            {
                $Message = "$($Path.FullName) already exists"
            }
            Else
            {
                $Path = New-Item -Path $Path.FullName -ItemType 'Directory'
            }

            $Parent = $Path.Parent
        }
        Else
        {
            $ItemParam = @{

                Path     = $env:Temp
                Name     = [System.IO.Path]::GetRandomFileName()
                ItemType = 'Directory'
            }
            $Parent = New-Item @ItemParam

            $ItemParam = @{

                Path     = $Parent.FullName
                Name     = 'Mount'
                ItemType = 'Directory'
            }
            $Path = New-Item @ItemParam
        }

        $ScratchPath = Join-Path -Path $Parent.FullName -ChildPath 'Scratch'

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

        $LogPath = Join-Path -Path $Parent.FullName -ChildPath 'Log'

        If
        (
            Test-Path -Path $LogPath
        )
        {
            $Log = Get-Item -Path $LogPath
        }
        Else
        {
            $Log = New-Item -Path $LogPath -ItemType 'Directory'
        }
    }

    Process
    {      
        $Argument = [System.Collections.Generic.List[System.String]]::new()

        Switch
        (
            $ImagePath.Extension
        )
        {
            '.wim'
            {                
                $Argument.Add( '/Mount-Wim'                           )
                $Argument.Add( "/WimFile=""$($ImagePath.FullName)"""  )
                $Argument.Add( "/Name=""$Name"""                      )
                $Argument.Add( "/MountDir=""$($Path.FullName)"""      )

                If
                (
                    $ReadOnly
                )
                {
                    $Argument.Add( '/ReadOnly'                        )
                }
            }

            Default
            {
                $Message = "Unexpected image type: `“$psItem`”"
                Write-Warning -Message $Message
            }
        }

        $DismParam = @{

            Argument = $Argument
            Log      = $Log
            Scratch  = $Scratch
        }
        $Dism = Start-Dism @DismParam
    }

    End
    {
        Return $Path
    }
}