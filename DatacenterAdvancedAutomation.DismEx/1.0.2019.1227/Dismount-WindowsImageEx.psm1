Set-StrictMode -Version 'Latest'

Function
Dismount-WindowsImageEx
{
    [cmdletBinding()]

    [outputType([System.IO.DirectoryInfo])]

    Param(

        [Parameter(
            Mandatory        = $True
        )]
        [System.IO.DirectoryInfo]
        $Path
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateSet('Discard','Save')]
        [System.String]
        $Action
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $CheckIntegrity
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Cleanup
    )

    Begin
    {
        $Parent = $Path.Parent

        $Image = Get-WindowsImage -Mounted | Where-Object -FilterScript {
                $psItem.Path -eq $path.FullName
        }

        If
        (
            $Image
        )
        {
            $ImagePath = Get-Item -Path $Image.ImagePath            

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
        Else
        {
            $Message = 'The image is not mounted'
            Write-Warning -Message $Message
        }
    }

    Process
    {
        If
        (
            Test-Path -Path 'Variable:\ImagePath'
        )
        {
            $TimeStamp = Get-Date -Format 'FileDateTime'

            $LogPath = Join-Path -Path $Log -ChildPath "Dism—$TimeStamp.txt"

            $ImageParam = @{
            
                Path             = $Path.FullName
                $Action          = $True                
                LogPath          = $LogPath
                LogLevel         = [Microsoft.Dism.Commands.LogLevel]::WarningsInfo
                ScratchDirectory = $Scratch.FullName
            }

            If
            (
                $CheckIntegrity
            )
            {
                Switch
                (
                    $Action
                )
                {
                    'Save'
                    {
                        $ImageParam.Add( 'CheckIntegrity', $CheckIntegrity )
                    }
                    
                    'Discard'
                    {
                        $Message = 'Check Integrity was specified, however it is only valid for Save action'
                        Write-Warning -Message $Message
                    }
                }
            }

            $Dism = Dismount-WindowsImage @ImageParam
        }
    }

    End
    {
        If
        (
            $Cleanup
        )
        {
            If
            (
                $Parent.Parent.FullName -eq ( Get-Item -Path $env:Temp ).FullName
            )
            {
                Remove-Item -Path $Parent.FullName -Recurse
            }
            Else
            {
                $Message = 'Cleanup was specified, however the path is not under Temp'
                Write-Warning -Message $Message
            }
        }

        If
        (
            Test-Path -Path 'Variable:\ImagePath'
        )
        {
            Return $ImagePath
        }      
    }
}