<#
    initialize and partition disk, return volume
#>

Set-StrictMode -Version 'Latest'

Function
Initialize-DiskEx
{
    [cmdletBinding()]

    Param(

            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [Microsoft.Management.Infrastructure.CimInstance]
            $Disk
        ,
            [Parameter(
                Mandatory = $True
            )]
            [ValidateNotNullOrEmpty()]
            [ValidateLength(0,32)]
            [System.String]
            $VolumeLabel
        ,
            [Parameter(
                Mandatory = $False
            )]
            [System.Management.Automation.SwitchParameter]
            $AssignDriveLetter
    )

    Begin
    {
        $Message = '  Entering Initalize-DiskEx'
        Write-Debug -Message $Message
    }

    Process
    {

      # Determine disk partition style

        If
        (
            $Disk.Size -lt 128mb
        )
        {
            $PartitionStyle = 'MBR'
        } 
        Else
        {
            $PartitionStyle = 'GPT'
        }

      # Initialize disk

        Set-Disk -InputObject $Disk -IsReadOnly $False
        Set-Disk -InputObject $Disk -IsOffline  $False
        Initialize-Disk -InputObject $Disk -PartitionStyle $PartitionStyle
    
      # Create partition

        $PartitionParam = @{

            InputObject       = $Disk
            UseMaximumSize    = $True
            AssignDriveLetter = [System.Boolean]$AssignDriveLetter
        }

        If
        (
            $PartitionStyle -eq 'MBR'
        )
        {
            $PartitionParam.Add( 'MbrType', 'IFS'   )
            $PartitionParam.Add( 'IsActive', $False )
        } 
        Else
        {
            $PartitionParam.Add( 'GptType', '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}' )
            $PartitionParam.Add( 'IsHidden', $False )
        }
    
        $Partition = New-Partition @PartitionParam

      # Format volume

        $Volume = Get-Volume -Partition $Partition
      
        $VolumeParam = @{

            InputObject          = $Volume
            NewFileSystemLabel   = $VolumeLabel
            Compress             = $False
            Full                 = $False
            Confirm              = $False
        }

        If
        (
            $AssignDriveLetter -or
            $VolumeLabel -like '*Witn*'
        )
        {
            $VolumeParam.add( 'FileSystem',           'NTFS' )
            $VolumeParam.add( 'AllocationUnitSize',    64kb  )
            $VolumeParam.add( 'UseLargeFRS',          $True  )
            $VolumeParam.add( 'ShortFileNameSupport', $False )
        }
        Else
        {
            $VolumeParam.add( 'FileSystem',           'ReFS' )
            $VolumeParam.add( 'SetIntegrityStreams',  $True  )
        }

        $Volume = Format-Volume @VolumeParam
    }

    End
    {
        $Message = '  Exiting Initalize-DiskEx'
        Write-Verbose -Message $Message

        Return $Volume
    }
}