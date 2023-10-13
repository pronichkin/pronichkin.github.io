<#
    create and connect shared virtual hard disks (VHDs)
#>

Set-StrictMode -Version 'Latest'

Function
New-vhdSet
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.Collections.Generic.List[Microsoft.HyperV.PowerShell.VirtualMachine]]
            $vm
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.String]
            $Name
        ,
            [Parameter(
                Mandatory = $False
            )]
            [System.String]
            $Path
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [System.UInt64]
            $Size
         <# [Parameter(
                Mandatory = $False
            )]
          # [ValidateNotNullOrEmpty()]
            [System.String[]]
            $HostName = "LocalHost"
        , #>
    )
        
    Begin
    {
      # Write-Verbose -Message $HostName.GetType().FullName

      # $HostName | ForEach-Object -Process { Write-Verbose -Message $psItem }

      # [System.String[]]$HostAddress = @( Resolve-dnsNameEx -Name $HostName | Sort-Object )

      # $Session = New-cimSessionEx -Name $HostAddress | Sort-Object -Property 'ComputerName'

        $cimSession = $vm.CimSession | Sort-Object -Property 'ComputerName' | Select-Object -First 1
        
      # $SessionCurrent = $Session | Select-Object -First 1
        
        Write-Debug -Message ( "Creating disk on host: " + $cimSession.ComputerName )

        If
        (
            [String]::IsNullOrWhiteSpace( $Path )
        )
        {
            $Path = ( Hyper-V\Get-vmHost -CimSession $cimSession ).VirtualHardDiskPath
        }

        $vhdFileName = $Name + ".vhds"
        $vhdPath     = Join-Path -Path $Path -ChildPath $vhdFileName
        
        $vhdParam = @{
        
            Path         = $vhdPath
            CimSession   = $cimSession
        }        

        If
        (
            Test-PathEx -cimSession $cimSession -Path $vhdPath
        )
        {
            $Message = 'File already exists, obtaining VHD'
            Write-Debug -Message $Message

            $vhd = Hyper-V\Get-VHD @vhdParam
        }
        Else
        {
          # Write-Verbose -Message ( "Host Address: " + $HostAddress[0] )

            $vhdParam.Add( 'SizeBytes', $Size )
            $vhdParam.Add( 'Dynamic',   $True )
        
            $Message = "Creating a VHD Set (VHDs) at $vhdPath"
            Write-Debug -Message $Message

         <# $vhdParam.GetEnumerator() | ForEach-Object -Process {

                Write-Verbose -Message ( "Name:  " + $psItem.Name )
                Write-Verbose -Message ( "Value: " + $psItem.Value )
            }  #>

            $vhd = Hyper-V\New-VHD @vhdParam
        }
    }

    Process
    {
      # Attach disk to all VMs

        $HardDiskDrive = [System.Collections.Generic.List[Microsoft.HyperV.PowerShell.HardDiskDrive]]::new()
        
        If
        (
            $vhd
        )
        {
            $vm | ForEach-Object -Process {
                
                $HardDrive = $psItem.HardDrives | Where-Object -FilterScript {
                    $psItem.Path -eq $vhd.Path
                }

                If
                (
                    $HardDrive
                )
                {
                    $Message = "Disk is already attached to $($psItem.Name)"
                    Write-Debug -Message $Message
                }
                Else
                {    
                    $Message = "Attaching disk to $($psItem.Name)"
                    Write-Debug -Message $Message

                    $vmHardDiskDriveParam = @{

                        VM                            = $psItem
                        Path                          = $vhd.Path
                        SupportPersistentReservations = $True
                        Passthru                      = $True
                    }
                    $HardDrive = Add-vmHardDiskDrive @vmHardDiskDriveParam
                }

                $HardDiskDrive.Add( $HardDrive )
            }
        }
    }

    End
    {
        Return $HardDiskDrive
    }
}