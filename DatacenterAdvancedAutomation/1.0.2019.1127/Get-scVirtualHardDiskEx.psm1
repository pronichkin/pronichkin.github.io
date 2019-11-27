<#
    fetch and tags a disk in Vmm library.
    If disk does not exist, create an empty one

    will find a matching disk based on criteria, including one
    with latst update if available
#>

Set-StrictMode -Version 'Latest'

Function
Get-scVirtualHardDiskEx
{
    [cmdletBinding()]
    
    Param(

        [Parameter(
            Mandatory = $False
        )]
        [System.String]
        [ValidateNotNullOrEmpty()]
        $Name
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.Boolean]
        [ValidateNotNullOrEmpty()]
        $Signed
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.String]
        [ValidateSet(
            'GPT',
            'MBR'
        )]
        $PartitionStyle
    ,
        [Parameter(
            Mandatory = $False
        )]
        [System.UInt64]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(512MB, 64TB)]
        $Size
    ,
        [Parameter(
            Mandatory = $False
        )]
        [Microsoft.SystemCenter.VirtualMachineManager.HostGroup]
        [ValidateNotNullOrEmpty()]
        $LibraryGroup
    ,
        [Parameter(
            Mandatory = $False
        )]
        [Microsoft.SystemCenter.VirtualMachineManager.LibraryShare]
        [ValidateNotNullOrEmpty()]
        $LibraryShare
    ,
        [Parameter(
            Mandatory = $False
        )]
        [Microsoft.SystemCenter.VirtualMachineManager.LibraryServer]
        [ValidateNotNullOrEmpty()]
        $LibraryServer
    ,
        [Parameter(
            Mandatory = $False
        )]
        [Microsoft.SystemCenter.VirtualMachineManager.Remoting.ServerConnection]
        [ValidateNotNullOrEmpty()]
        $vmmServer
    )

    Process
    {
        If
        (
            $Name
        )
        {
            $Message = "  Looking for suitable Virtual hard disk `“$Name`”"
            Write-Verbose -Message $Message
        }
        ElseIf
        (
            $Size
        )
        {
            $Name = 'Empty ' + ( $Size / 1gb ) + ' GB'
        }
        Else
        {
            $Message = 'Neither “Name” nor “Size” were specified, unable to locate a disk'
            Write-Error -Message $Message
        }

        If
        (
            $LibraryGroup
        )
        {
            $vmmServer = $LibraryGroup.ServerConnection
        }
        ElseIf
        (
            $LibraryShare
        )
        {
            $vmmServer = $LibraryShare.ServerConnection
        }
        ElseIf
        (
            $LibraryServer   
        )
        {
            $vmmServer = $LibraryServer.ServerConnection
        }
        ElseIf
        (
            $vmmServer
        )
        {
            $Message = "Using explicitly specified VMM Server `“$( $vmmServer.Name )`”"
            Write-Debug -Message $Message
        }
        Else
        {
            $Message = 'Please specify at least one of the following: Library Group, Library Server, Library Share and/or VMM Server'
            Write-Error -Message $Message
        }

        $VirtualHardDiskParam = @{

            Name      = $Name
            Type      = 'VirtualHardDisk'
            vmmServer = $vmmServer
        }        

        If
        (
            $LibraryGroup
        )
        {
            $VirtualHardDiskParam.Add(

                'LibraryGroup', $LibraryGroup
            )
        }

        [System.Collections.Generic.List[
            Microsoft.SystemCenter.VirtualMachineManager.StandaloneVirtualHardDisk
        ]]$VirtualHardDisk = Get-scLibraryItemEx @VirtualHardDiskParam |
            Where-Object -FilterScript { $psItem.Shielded -eq $Signed }

        If
        (
            $LibraryServer
        )
        {
            $VirtualHardDisk = $VirtualHardDisk |
                Where-Object -FilterScript {
                    $psItem.LibraryServer -eq $LibraryServer
                }
        }
        
        If
        (
            $LibraryShare
        )
        {
            $VirtualHardDisk = $VirtualHardDisk |
                Where-Object -FilterScript {
                    $psItem.LibraryShareId -eq $LibraryShare.ID
                }
        }

        If
        (
            $VirtualHardDisk
        )
        {
            If
            (
                $PartitionStyle
            )
            {
                $VirtualHardDisk = $VirtualHardDisk |
                    Where-Object -FilterScript {
                        $psItem.Tag -contains $PartitionStyle
                    }
            }

            If
            (        
                @( $VirtualHardDisk ).Count -gt 1
            )
            {
             <# Do not ouptput details because now all the real filtering based
                on “Release” property is done by “Get-scLibraryItemEx”

                $Message = "  Located $( @($VirtualHardDisk).Count ) Disks"
                Write-Verbose -Message $Message

                $VirtualHardDisk | Sort-Object -Property 'Name' | ForEach-Object -Process {

                    $Message = '    * ' + $psItem.Name
                    Write-Verbose -Message $Message
                }  #>

                $VirtualHardDisk = $VirtualHardDisk | Select-Object -First 1

                $Message = "  Located Virtual Hard Disk Disk `“$( $VirtualHardDisk.Name )`”"
                Write-Verbose -Message $Message
            }
            Else            
            {
                $Message = "  Located Virtual Hard Disk Disk `“$( $VirtualHardDisk.Name )`”"
                Write-Verbose -Message $Message
            }
        }
        ElseIf
        (
            $LibraryShare -And $Size
        )
        {
            $Message = "Creating Virtual Hard Disk `“$Name`” at `“$( $LibraryShare.Path )`”"
            Write-Verbose -Message $Message

            $VirtualHardDiskParam = @{

                Path   = $LibraryShare.Path
                Name   = $Name
                Format = 'VHDX'
                Size   = $Size
            }
            $vhd = New-VHDex @VirtualHardDiskParam

          # Start-Sleep -Seconds 10

            $LibraryShare = Read-scLibraryShare -LibraryShare $LibraryShare
        
            [System.Collections.Generic.List[
                Microsoft.SystemCenter.VirtualMachineManager.StandaloneVirtualHardDisk
            ]]$VirtualHardDisk = Get-scVirtualHardDisk -vmmServer $vmmServer |
                Where-Object -FilterScript $FilterScript

         <# We need to loop thru the collection just in case multiple objects
            came up, e.g. if the newly creatd one was replicated immediately to
            other libraries using DFS-R  #>

            $VirtualHardDisk | ForEach-Object -Process {

                $VirtualHardDiskParam = @{

                    VirtualHardDisk        = $psItem
                    Name                   = $Name
                    Description            = 'Empty optional disk for customer application data'                
                    FamilyName             = $Name
                    Release                = '1.0.0.0'
                    VirtualizationPlatform = 'HyperV'
                    OperatingSystem        = 'None'
                }
                [System.Void]( Set-scVirtualHardDisk @VirtualHardDiskParam )
            }

            $VirtualHardDisk = $VirtualHardDisk |
                Where-Object -FilterScript {
                    $psItem.LibraryShareId -eq $LibraryShare.ID
                }
        }
        Else
        {
            $Message = 'No matching Virtual Hard Disk was located, however “Library Share” and/or “Size” were not specified. You need to provide both to create a new disk'
            Write-Error -Message $Message
        }

        Return $VirtualHardDisk
    }
}