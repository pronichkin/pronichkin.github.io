<#
    This is a wrapper for “Management Pack XML Writer” which saves unsealed
    Management Pack as an XML
#>

Function
Write-ManagementPackEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.EnterpriseManagement.Configuration.ManagementPack]
        $ManagementPack
    ,
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Path
    )

    Process
    {
        $Name = $ManagementPack.Name + ' — ' + $ManagementPack.Version

        Write-Verbose -Message $Name

        $Path = Join-Path -Path $Path -ChildPath $Name

        If
        (
            Test-Path -Path $Path
        )
        {
            $Message = '  This Management Pack has been already expanded. Skipping'
            Write-Verbose -Message $Message

            $Path = Get-Item -Path $Path
        }
        Else
        {
            $Path = New-Item -Path $Path -ItemType 'Directory'

            $ManagementPackXmlWriter = [Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackXmlWriter]::new( $Path.FullName )

            $ManagementPackPath = $ManagementPackXmlWriter.WriteManagementPack( $ManagementPack )

            $ManagementPackXml = [System.Xml.XmlDocument]( Get-Content -Path $ManagementPackPath )

            Export-ManagementPack -ManagementPack $ManagementPackXml -Path $Path
        }

        Return $Path
    }
}