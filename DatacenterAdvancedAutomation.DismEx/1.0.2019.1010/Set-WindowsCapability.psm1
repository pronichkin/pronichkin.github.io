Set-StrictMode -Version 'Latest'

Function
Set-WindowsCapability
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.psSession[]]
        $Session
    )

    $ScriptBlock = {

        $Message = "Disabling Capabilities on $( $env:ComputerName )"
        Write-Verbose -Message $Message

        $Capability = Get-WindowsCapability -Online | Where-Object -FilterScript {

            $psItem.State -eq 'Installed' -and
            $psItem.Name -like 'Language*' -and
            $psItem.Name -notlike 'Language.Basic~~~en-US*'
        }

        $Restart = $False

        $Capability | ForEach-Object -Process {

            $Remove = Remove-WindowsCapability -Online -Name $psItem.Name

            If
            (
                $Remove.RestartNeeded
            )
            {
                $Restart = $True
            }   
        }
    }

    $ImageInfo = Get-WindowsImageInfo -ComputerName $Session.ComputerName
    $ReleaseId = $ImageInfo.GetValue( 'ReleaseId' )

    If
    (
        $ReleaseId -ge 1809
    )
    {
        $CommandParam = @{

            Session      = $Session
            ScriptBlock  = $ScriptBlock
        }
        $OptionalFeature = Invoke-Command @CommandParam
    }
    Else
    {
        $Message = "Setting Windows Capability does not work on Windows version $ReleaseId"
        Write-Verbose -Message $Message
    }
}