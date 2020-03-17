Using Module '.\ElementType.psm1'
Using Module '.\DeviceType.psm1'

Import-Module -Name 'Storage' -Verbose:$False

<#
    Formats value of “Device” property for meaningful display
    
    Note

    Formatted output is not intended for programmatic use (e.g. consumption
    from pipeline or variables.) “Get-bcdElement” provides raw output 
    which is more suitable for these scenarios
#>

Function
Get-bcdElementDevice
{
    [CmdletBinding()]

    Param(

        [Parameter(
            ParameterSetName  = 'Device',
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Device
    ,
        [Parameter(
            ParameterSetName  = 'Element',
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Element
    ,

      # Expand known values, recursively, and add helpful metadata

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Expand
    ,

      # Format for human-readable output

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Format
    )

    Begin
    {
     <# If “Element” was specified, it can be used to retreive additional
        options (e.g. referenced objects.) This is typically not the
        case for “Parent” object because you cannot run additional queries
        for it  #>

        Switch
        (
            $psCmdLet.ParameterSetName
        )
        {
            'Element'
            {
                $Device = $Element.Device

                If
                (
                    $Element.StoreFilePath
                )
                {
                 <# WMI format:
                    \??\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd
                    File system format:
                    \\?\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd

                    Because we obtained path from properties of WMI object and will use
                    it in a standard PowerShell cmdlet, we need to convert from former
                    into the latter.

                    Note that it won't be needed if the path is rooted to a drive letter
                  #>

                    $Path  = $Element.StoreFilePath.Replace( '\??\', '\\?\' )
                  # .Replace( '\??\', [System.String]::Empty )
                    $Item  = Get-Item -Path $Path
                    $Store = Get-bcdStore -File $Item
                }
                Else
                {
                    $Store = Get-bcdStore
                }
            }
        }
    }

    Process
    {
        $Value = @{
        
            DeviceType = [DeviceType]$Device.DeviceType
        }

        $ElementParam = @{

            Expand = $Expand
            Format = $Format
        }

        Switch
        (
            $Device.DeviceType
        )
        {
            1  # Boot
            {
              # No more properties to populate
            }
    
            2  # Partition
            {   
                If
                (
                    $Element
                )
                {
                  # We can query for the same Element as “Qualified Partition”
                  # to retrieve more information

                    $ObjectParam = @{

                        Store  = $Store
                        Id     = $Element.ObjectId
                      # Expand = $Expand
                      # Format = $Format
                    }
                    $Object             = Get-bcdObject @ObjectParam

                    $ElementQualified   = Get-bcdElement -Object $Object -Type $Element.Type -Flag Qualified

                    $ElementParamCurrent = $ElementParam.Clone()
                    $ElementParamCurrent.Add( 'Device', $ElementQualified.Device )

                    $PartitionQualified = Get-bcdElementDevice @ElementParamCurrent

                    $Value.Add( 'Partition', $PartitionQualified.Partition )

                 <# “Element” is the preferred query method because it provides
                    metadata, such as “Store File Path”, “Object ID” and “Type”.
                    This allows to look up referred objects in the same Store,
                    as well as to query for the same Element with different
                    Flags  #>

                    $ElementParam.Add( 'Element', $Element )
                }
                Else
                {
                 <# “Device” is a fallback query path. It only allows to check
                    whether value was specified and warn the user that data
                    cannot be resolved  #>

                    $ElementParam.Add( 'Device', $Device )
                }

                $AdditionalOption = Get-bcdElementAdditionalOption @ElementParam

                $Value.Add( 'Additional Options'  ,  $AdditionalOption )
                $Value.Add( 'Path'                ,  $Device.Path      )
            }

            3  # File
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }

            4  # Ramdisk
            {
                $ElementParamCurrent = $ElementParam.Clone()
                $ElementParamCurrent.Add( 'Device', $Device.Parent )

                $Parent = Get-bcdElementDevice @ElementParamCurrent

                If
                (
                    $Element
                )
                {
                 <# “Element” is the preferred query method because it provides
                    metadata, such as “Store File Path”, “Object ID” and “Type”.
                    This allows to look up referred objects in the same Store,
                    as well as to query for the same Element with different
                    Flags  #>

                    $ElementParam.Add( 'Element', $Element )
                }
                Else
                {
                 <# “Device” is a fallback query path. It only allows to check
                    whether value was specified and warn the user that data
                    cannot be resolved  #>

                    $ElementParam.Add( 'Device', $Device )
                }

                $AdditionalOption = Get-bcdElementAdditionalOption @ElementParam

                $Value.Add( 'Additional Options'  ,  $AdditionalOption )
                $Value.Add( 'Parent'              ,  $Parent           )
                $Value.Add( 'Path'                ,  $Device.Path      )
            }
            
            5  # Unknown
            {
                $Value.Add( 'Data'                ,  $Device.Data      )
            }
    
            6  # QualifiedPartition
            {
                $Disk      = Get-Disk | Where-Object -FilterScript {
                    $psItem.Guid -eq $Device.DiskSignature
                }

                If
                (
                    $Disk
                )
                {
                    $Partition = Get-Partition -Disk $Disk | Where-Object -FilterScript {
                        $psItem.Guid -eq $Device.PartitionIdentifier
                    }
                }
                Else
                {
                    $Message = "Cannot locate disk with Signature $($Device.DiskSignature)"
                    Write-Warning -Message $Message

                    $Partition = $null
                }

                $Value.Add( 'Partition'           ,  $Partition        )

                If
                (
                    $Element
                )
                {
                 <# “Element” is the preferred query method because it provides
                    metadata, such as “Store File Path”, “Object ID” and “Type”.
                    This allows to look up referred objects in the same Store,
                    as well as to query for the same Element with different
                    Flags  #>

                    $ElementParam.Add( 'Element', $Element )
                }
                Else
                {
                 <# “Device” is a fallback query path. It only allows to check
                    whether value was specified and warn the user that data
                    cannot be resolved  #>

                    $ElementParam.Add( 'Device', $Device )
                }

                $AdditionalOption = Get-bcdElementAdditionalOption @ElementParam

                $Value.Add( 'Additional Options'  ,  $AdditionalOption )
            }

            7  # Locate
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }            
            
            8  # LocateEx
            {
              # Not properly implemented yet, looking for real world examples

                $Value.Add( 'Path'                ,  $Device.Path      )
            }

            Default
            {
                $Message = 'Unknonw device type'
                Write-Warning -Message $Message
            }
        }
    }

    End
    {
        If
        (
            $Format
        )
        {
            $Property = @()

            $Value.GetEnumerator() | ForEach-Object -Process {

                $Label = $psItem.Key

                $StringBuilder = [System.Text.StringBuilder]::New()

                [System.Void]( $StringBuilder.Append( '$psItem[ '''  ) )
                [System.Void]( $StringBuilder.Append( "$Label"       ) )
                [System.Void]( $StringBuilder.Append( ''' ]'         ) )

                $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( 
                            
                    $StringBuilder.ToString()
                )

                $Property += @{

                    Label      = $Label
                    Expression = $ScriptBlock
                }
            }

            Return Select-Object -InputObject $Value -Property $Property
        }
        Else
        {
            Return $Value
        }
    }
}