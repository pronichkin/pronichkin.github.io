Function
New-scStorageVolumeEx
{
    [cmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $True
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.SystemCenter.VirtualMachineManager.HostCluster]
        $vmHostCluster
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.string]
        $StorageClassificationNameDefault = 's2d'
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [System.string]
        $StorageClassificationNamePerformance = 's2d Fast'
    )

    Process
    {
        $StorageProvider = Get-scStorageProvider | Where-Object -FilterScript {
            $psItem.Name -eq $vmHostCluster.Name
        }

        If
        (
            $StorageProvider
        )
        {
            $Message = 'The cluster already has Storage Spaces Direct (S2D) enabled'
            Write-Verbose -Message $Message
        }
        Else
        {
            $Message = 'Enabling Storage Spaces Direct (S2D)'
            Write-Verbose -Message $Message

            $vmHostClusterNode = $vmHostCluster.Nodes | Sort-Object -Property 'Name' | Select-Object -First 1
        
            $SessionParam = @{

                ComputerName = $vmHostClusterNode.Name
                Verbose      = $False
            }
            $Session = New-CimSession @SessionParam

            $StorageSpacesDirectParam = @{

                CimSession    = $Session
                Autoconfig    = $True
                Confirm       = $False
                Verbose       = $False
                WarningAction = 'SilentlyContinue'
            }
            [System.Void]( Enable-ClusterStorageSpacesDirect @StorageSpacesDirectParam )

            $vmHostCluster = Read-scvmHostCluster -vmHostCluster $vmHostCluster

            $StorageProvider = Get-scStorageProvider -Name $vmHostCluster.Name

            $Message = 'Refreshing the Storage Provider. This might take a while'
            Write-Verbose -Message $Message

            $StorageProvider = Read-scStorageProvider -StorageProvider $StorageProvider
        }

        $Message = "Automatically creating storage volumes on Storage Spaces Direct (S2D) cluster `“$( $vmHostCluster.Name )`”"
        Write-Verbose -Message $Message

        $StorageClassificationDefault     = Get-scStorageClassification -Name $StorageClassificationNameDefault
        $StorageClassificationPerformance = Get-scStorageClassification -Name $StorageClassificationNamePerformance

      # This does not work
        $StorageArray    = Get-scStorageArray -HyperConvergedHostCluster $vmHostCluster

        $StorageArray    = $StorageProvider.StorageArrays[0]
        $StoragePool     = $StorageArray.StoragePools[0]

        $StoragePool     = Set-scStoragePool -StoragePool $StoragePool -StorageClassification $StorageClassificationDefault

        $StorageVolume = [System.Collections.Generic.List[
            Microsoft.SystemCenter.VirtualMachineManager.StorageVolume
        ]]::new()

       #region Volume size calculation

          # NOTE this assumes we're only using Mirror
          # if mixing different resiliency settings, the calculation
          # would be a little more complicated.

          # We need as many disks, as number of nodes in the cluster

            $VolumeSizeRaw = $StoragePool.RemainingManagedSpace / $vmHostCluster.Nodes.Count

          # Each disk will take 3x space because we use Mirror

            $StorageEfficiency = 1/3

            $VolumeSizeUsable = $VolumeSizeRaw * $StorageEfficiency

          # We will round the size to given scale
          # to have a nicer veiw (and some spare disk space)

            $Scale = 10tb

            $VolumeSizeScale = $VolumeSizeUsable / $Scale
            $VolumeSizeRound = [System.Math]::Round( $VolumeSizeScale )

          # Finally we need to bring it back to bytes

            $VolumeSize = $VolumeSizeRound * $Scale

       #endregion Volume size calculation

        1..$vmHostCluster.Nodes.Count | ForEach-Object -Process {

            $Name = "Mirror $( $psItem.ToString( '00' ) )"
        
            $StorageVolumeCurrent = Get-scStorageVolume -StorageArray $StorageArray |
                Where-Object -FilterScript { $psItem.VolumeLabel -eq $Name }

            If
            (
                $StorageVolumeCurrent
            )
            {
                $Message = "  Volume `“$Name`” was already created"
                Write-Verbose -Message $Message
            }
            Else
            {
                $Message = "  Volume `“$Name`”, $( $VolumeSize/1tb ) TB"
                Write-Verbose -Message $Message

                $StorageVolumeParam = @{

                    Name                  = $Name
                    StoragePool           = $StoragePool
                    StorageArray          = $StorageArray
                    GuidPartitionTable    = $True
                    StorageClassification = $StorageClassificationPerformance
                    SizeInBytes           = $VolumeSize
                    FileSystem            = 'CSVFS_ReFS'
                    ResiliencySettingName = 'Mirror'
                }
                $StorageVolume.Add( ( New-scStorageVolume @StorageVolumeParam ) )

                $Path = "\\$( $vmHostCluster )\ClusterStorage$\Volume1"

                If
                (
                    Test-Path -Path $Path
                )
                {
                    Rename-Item -Path $Path -NewName $Name
                }
                Else
                {
                    $Message = "      Path `“$Path`” does not exist, the proper name `“$Name`” is likely already used. Skipping rename"
                    Write-Debug -Message $Message
                }
            }
        }

        If
        (
            $StorageVolume
        )
        {  
            $Message = 'Refreshing the cluster to pick up the new volume names'
            Write-Verbose -Message $Message
    
            $vmHostCluster = Read-scvmHostCluster -vmHostCluster $vmHostCluster

            $Message = 'Refreshing the Storage Provider. This might take a while'
            Write-Verbose -Message $Message

            $StorageProvider = Read-scStorageProvider -StorageProvider $StorageProvider
        }
        Else
        {
            $Message = 'No new volumes were created'
            Write-Verbose -Message $Message
        }
    }
}