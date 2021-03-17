    [System.String]                                    $SerialNumber = 'NAABJRCZ'
    [System.String]                                    $ComputerName = 'ArtemP27s.local'
    [System.String]                                    $Name         = 'ArtemP24v'

    [System.Management.Automation.psCredential]        $Credential   =  Get-Credential
    [Microsoft.Management.Infrastructure.cimSession]   $cimSession   =  New-cimSession -ComputerName $ComputerName -Credential $Credential
    [System.Management.Automation.Runspaces.psSession] $psSession    =  New-psSession  -ComputerName $ComputerName -Credential $Credential
    [Microsoft.HyperV.PowerShell.VirtualMachine]       $vm           =  Get-VM -cimSession $cimSession -Name $Name
    [Microsoft.HyperV.PowerShell.vmScsiController]     $Controller   =  Get-vmScsiController -vm $vm -ControllerNumber 0
    [System.String]                                    $Filter       =  "SerialNumber like ""%$SerialNumber"""
    
    [System.Collections.Generic.List[System.String]]   $Diskpart     = [System.Collections.Generic.List[System.String]]::new()
    $Diskpart.Add( 'Rescan'    )
    $Diskpart.Add( 'List disk' )

    [Microsoft.Management.Infrastructure.cimInstance]  $Disk         =  $null    

    while
    (
       -not $Disk
    )
    {
        Write-Verbose -Message 'Waiting for the disk'
    
        [System.Collections.Generic.List[System.String]]   $Command      =  Invoke-Command -Session $psSession -ScriptBlock { $using:Diskpart | diskpart.exe }
        [Microsoft.Management.Infrastructure.cimInstance]  $Disk         =  Get-CimInstance -CimSession $cimSession -ClassName 'win32_DiskDrive' -Filter $Filter -Verbose:$False
    }

  # [Microsoft.HyperV.PowerShell.HardDiskDrive]        $Drive        =  $Controller.Drives | Where-Object -FilterScript { -not $psItem.Path }
    [Microsoft.HyperV.PowerShell.HardDiskDrive]        $Drive        =  $Controller.Drives | Where-Object -FilterScript { $psItem.DiskNumber -eq $Disk.Index }

    $Drive = Remove-vmHardDiskDrive -vmHardDiskDrive $Drive -Passthru
    $Drive = Add-vmHardDiskDrive -vmDriveController $Controller -DiskNumber $Disk.Index -Passthru