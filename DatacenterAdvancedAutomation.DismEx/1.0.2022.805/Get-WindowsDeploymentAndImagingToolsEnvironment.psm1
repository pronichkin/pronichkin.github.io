Set-StrictMode -Version 'Latest'

<#
   .SYNOPSIS
    Get Windows ADK path value

   .DESCRIPTION
    Mocked after `DandISetEnv.bat` (Deployment and Imaging Tools Environment)

    Note that the path are not validated, and many tools might be not present
#>

function
Get-WindowsDeploymentAndImagingToolsEnvironment
{
    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.Dictionary[
            System.String,
            System.IO.DirectoryInfo
        ]]
    )]

    param
    (
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [System.Management.Automation.ValidateNotNullOrEmptyAttribute()]
        [System.String]
      # Name of the “Kits root” key
        $KitsRootRegValueName = 'KitsRoot10'
    )

    begin
    {}

    process
    {
        $return = [System.Collections.Generic.Dictionary[
            [System.String],
            [System.IO.DirectoryInfo]
        ]]::new()

        if
        (
            Test-Path -Path 'HKLM:\Software\Microsoft\Windows Kits\Installed Roots'
        )
        {
            $regKeyPath = 'HKLM:\Software\Microsoft\Windows Kits\Installed Roots'
        }
        else
        {
            $regKeyPath = 'HKLM:\Software\Wow6432Node\Microsoft\Windows Kits\Installed Roots'
        }

        $return.Add(
            'KitsRoot',
            [System.IO.DirectoryInfo]( Get-ItemProperty -Path $regKeyPath -Name $KitsRootRegValueName | Select-Object -ExpandProperty $KitsRootRegValueName )
        )
        
      # Build the D&I Root from the queried KitsRoot
        $return.Add(
            'DandIRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.KitsRoot.FullName,
                'Assessment and Deployment Kit\Deployment Tools'
            )
        )

      # Construct the path to WinPE directory, architecture-independent
        $return.Add(
            'WinPERoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.KitsRoot.FullName,
                'Assessment and Deployment Kit\Windows Preinstallation Environment'
            )
        )

        $return.Add(
            'WinPERootNoArch',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.KitsRoot.FullName,
                'Assessment and Deployment Kit\Windows Preinstallation Environment'
            )
        )

      # Construct the path to DISM, Setup and USMT, architecture-independent
        $return.Add(
            'WindowsSetupRootNoArch',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.KitsRoot.FullName,
                'Assessment and Deployment Kit\Windows Setup'
            )
        )
        
        $return.Add(
            'USMTRootNoArch',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.KitsRoot.FullName,
                'Assessment and Deployment Kit\User State Migration Tool'
            )
        )

      # Constructing tools paths relevant to the current Processor Architecture
        $return.Add(
            'DISMRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                $env:processor_architecture,
                'DISM'
            )
        )
        $return.Add(
            'BCDBootRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                $env:processor_architecture,
                'BCDBoot'
            )
        )
        $return.Add(
            'ImagingRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                $env:processor_architecture,
                'Imaging'
            )
        )
        $return.Add(
            'OSCDImgRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                $env:processor_architecture,
                'Oscdimg'
            )
        )
        $return.Add(
            'WdsmcastRoot',
                [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                $env:processor_architecture,
                'Wdsmcast'
            )
        )

      # Now do the paths that apply to all architectures
        $return.Add(
            'HelpIndexerRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                'HelpIndexer'
            )
        )
        $return.Add(
            'WSIMRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.DandIRoot.FullName,
                'WSIM'
            )
        )

      # Set ICDRoot. ICD is X86 only
        $return.Add(
            'ICDRoot',
            [System.IO.DirectoryInfo][System.IO.Path]::Combine(
                $return.KitsRoot.FullName,
                'Assessment and Deployment Kit\Imaging and Configuration Designer\x86'
            )
        )

        return $return
    }

    end
    {}
}

$aliasParam = @{
    Name        = 'Get-DandISetEnv'
    Value       = 'Get-WindowsDeploymentAndImagingToolsEnvironment'
    Description = 'Shorter version'
}
New-Alias @aliasParam