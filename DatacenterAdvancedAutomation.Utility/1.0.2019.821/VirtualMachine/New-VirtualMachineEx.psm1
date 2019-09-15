Function
New-VirtualMachineEx
{
    [cmdletBinding()]

    Param(

        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name = [System.IO.Path]::GetRandomFileName()
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int64]
        $Memory = 8gb
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $Cpu    = 4
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.DirectoryInfo]
        $Path
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Vhd.PowerShell.VirtualHardDisk]
        $VirtualHardDisk
    ,
        [Parameter(
            Mandatory        = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession]
        $cimSession
    )

    Process
    {
        $vmParam = @{

            Name               = $Name
            MemoryStartupBytes = 1gb
            Generation         = 2
        }

        If
        (
            $cimSession
        )
        {
            $h = Hyper-V\Get-VMHost -CimSession $cimSession
            $vmParam.Add( 'cimSession', $cimSession )
        }
        Else
        {
            $h = Hyper-V\Get-VMHost
        }

        $vmParam.Add( 'Version', $h.SupportedVmVersions[-3] )

        If
        (
            $Path
        )
        {
            $vmParam.Add( 'Path', $Path.FullName )
        }
        Else
        {
            $vmParam.Add( 'Path', $h.VirtualMachinePath )
        }

        If
        (
            $VirtualHardDisk
        )
        {
            $vmParam.Add( 'VHDPath', $VirtualHardDisk.Path )
        }
        
        $vm = Hyper-V\New-vm @vmParam

        Hyper-V\Set-vmProcessor    -vm $vm -Count $Cpu

        $MemoryParam = @{

            vm                   = $vm
            DynamicMemoryEnabled = $True
            StartupBytes         = 1gb
            MinimumBytes         = 1gb
            MaximumBytes         = $Memory
        }
        Hyper-V\Set-vmMemory @MemoryParam

        Return $vm
    }
}