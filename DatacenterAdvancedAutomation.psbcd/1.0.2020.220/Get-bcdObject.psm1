using module '.\ObjectType.psm1'
using module '.\ObjectWellKnown.psm1'

Function
Get-bcdObject
{
    [OutputType(
        'Microsoft.Management.Infrastructure.cimInstance#Root/WMI/bcdObject'
    )]

    [CmdletBinding(
        DefaultParameterSetName = 'List'
    )]

    Param
    (
        [Parameter(
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [ValidateNotNullOrEmpty()]
        [psTypeName(
            'Microsoft.Management.Infrastructure.cimInstance#Root/WMI/bcdStore'
        )]
        [Microsoft.Management.Infrastructure.cimInstance]
        $Store
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Type'
        )]
        [ObjectType[]]
      # [System.uInt32]
        $Type
    ,
        [Parameter(
            Mandatory        = $True,
            ParameterSetName = 'Id'
        )]
        [System.Guid[]]
        $Id
    ,
        [Parameter(
            Mandatory        = $False,
            ParameterSetName = 'Well-Known'
        )]
        [ArgumentCompleter(
            {
                $ObjectWellKnown.Keys
            }
        )]
        [ValidateScript(
            {
                $ObjectWellKnown.ContainsKey( $psItem )
            }
        )]
        [System.String[]]
        $WellKnownID
    ,

      # Expand known values, recursively, and add helpful metadata
      # This mode is mostly intended for programmatic parsing

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Expand
    ,

      # Format for human-readable output. This mode is mostly intended for
      # manual exploration of child objects

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Format
    )

    Process
    {
       #region Raw (basic API call)

          # Prepare variable

            If
            (
               -Not $Store
            )
            {
                $Store = Get-bcdStore
            }

            $MethodParam = @{
        
                cimInstance = $Store
                Verbose     = $False
            }

          # Handle different modes

            Switch
            (
                $psCmdlet.ParameterSetName
            )
            {
                'Id'
                {
                    If
                    (
                        @( $Id ).Count -eq 1
                    )
                    {
                        $Message = "Retrieving BCD object with ID `{$Id`}"
                        Write-Debug -Message $Message

                        $Argument = @{
                
                            'Id' = [System.String]'{' + $Id[0].Guid + '}'
                        }

                        $MethodParam.Add( 'MethodName', 'OpenObject' )
                    }
                    Else
                    {
                        $Raw = $Id | ForEach-Object -Process {

                            Get-bcdObject -Store $Store -Id $psItem
                        } #| Sort-Object -Unique -Property 'Id'
                    }
                }

                'Well-Known'
                {
                    $Raw = $WellKnownID | ForEach-Object -Process {

                     <# $WellKnownIdCurrent = $psItem

                        $IdCurrent = $ObjectWellKnown.GetEnumerator() | Where-Object -FilterScript {
                            $psItem.Value -eq $WellKnownIdCurrent
                        }  #>

                        $IdCurrent = $ObjectWellKnown[ $psItem ]

                        $Message = [System.String]::Empty
                        $Message += "Retrieving well-known object `“$psItem`”"
                      # $Message += " with ID `{$($IdCurrent.Key)`} from Store"
                        $Message += " with ID `{$IdCurrent`} from Store"
                        $Message += " `“$($Store.FilePath)`”"
                        Write-Debug -Message $Message

                        Get-bcdObject -Store $Store -Id $IdCurrent
                    }
                }

                'Type'
                {
                    If
                    (
                        @( $Type ).Count -eq 1
                    )
                    {
                        $Message  = [System.String]::Empty
                        $Message += "Enumerating BCD objects of type `“$Type`”"
                        $Message += " in Store `“$($Store.FilePath)`”"
                        Write-Debug -Message $Message

                        $Argument = @{

                            'Type' = $Type[0]
                        }

                        $MethodParam.Add( 'MethodName', 'EnumerateObjects' )
                    }
                    Else
                    {
                        $Raw = $Type | ForEach-Object -Process {

                            Get-bcdObject -Store $Store -Type $psItem
                        } #| Sort-Object -Unique -Property 'Id'
                    }
                }

                'List'
                {
                    $Message  = [System.String]::Empty
                    $Message += "Type or ID were not specified. Listing all "
                    $Message += "BCD objects of known types in store "
                    $Message += "`“$($Store.FilePath)`”"
                    Write-Debug -Message $Message

                    $Raw =
                        [ObjectType].GetEnumValues() | ForEach-Object -Process {

                        Get-bcdObject -Store $Store -Type $psItem
                    } #| Sort-Object -Unique -Property 'Id'
                }

             <# The following is indicator that we're running in one of the
                modes which involve actual query  #>

                {
                    $MethodParam[ 'MethodName' ]
                }
                {
                    $MethodParam.Add( 'Arguments',  $Argument )

                    $Object = Invoke-CimMethod @MethodParam

                    If
                    (
                        $Object.ReturnValue
                    )
                    {
                        Switch
                        (
                            $psCmdlet.ParameterSetName
                        )
                        {
                            'Type'
                            {
                                $Raw = $Object.Objects
                            }

                            'Id'
                            {
                                $Raw = $Object.Object
                            }

                            Default
                            {
                                Throw 'Unresolved parameter set'
                            }
                        }
                    }
                    Else
                    {
                        $Message  = [System.String]::Empty
                        $Message += 'No BCD objects satisfying the criteria'
                        $Message += ' specified were found in Store'
                        $Message += " `“$($Store.FilePath)`”"
                        Write-Warning -Message $Message

                     <# Need to initialize the variable nevertheless for future
                        processing  #>

                        $Raw = @()
                    }
                }

                Default
                {
                    Throw 'Unresolved parameter set'
                }
            }

       #endregion Raw (basic API call)

       #region Process (Expand and Format)

            If
            (
                $Expand -or
                $Format
            )
            {
               #region Expand

                    $Expanded = [System.Collections.Generic.Dictionary[
                   
                      # “IdEx” describes ID and Object Type
                        System.Collections.Generic.Dictionary[
                            System.String, System.Object

                      # Dictionary of Elements
                      # ], [System.Collections.Generic.Dictionary[
                   
                      #   # “TypeEx” describes Type and associated Format
                      #     System.Collections.Generic.Dictionary[
                      #         System.String, System.Object
                    
                      #   # Value which can be of various types
                      #     ], System.Object
                      # ]]

                        ], System.Object
                    ]]::New()

                    $Raw | ForEach-Object -Process {

                        $ObjectCurrent = $psItem
                    
                        $IdEx = [System.Collections.Generic.Dictionary[
                            System.String, System.Object
                        ]]::new()

                        $IdEx.Add( 'Id'   , [System.Guid] $ObjectCurrent.Id   )
                        $IdEx.Add( 'Type' , [ObjectType]  $ObjectCurrent.Type )
                  
                        $ElementParam = @{

                            Object = $psItem
                            Expand = $Expand
                            Format = $Format
                        }
                        $Element = Get-bcdElement @ElementParam
                    
                        $Expanded.Add( $IdEx, $Element )
                    }

               #endregion Expand
               
                If
                (
                    $Format
                )
                {
                   #region Format

                      # Generic properties which apply to any object

                        $Property = @(

                            @{
                                Label      = 'ID'
                                Expression = { $psItem.Key.Id }
                            }

                            @{

                                Label      = 'Type'
                                Expression = { $psItem.Key.Type }
                            }
                        )

                      # Unique properties which are unique per object
                    
                        $Formatted = $Expanded.GetEnumerator() |
                            ForEach-Object -Process { 

                            $ExpandedCurrent = $psItem

                         <# Clone the list of properties so that we can append
                            it with the properties which are specific for the
                            current object  #>

                            $PropertyCurrent = $Property

                         <# A property to specify a well-known object ID, if 
                            applicable  #>

                          # $ObjectWellKnownCurrent = $ObjectWellKnown[ $ExpandedCurrent.Key.Id ]

                            $ObjectWellKnownCurrent =
                                $ObjectWellKnown.GetEnumerator() |
                                    Where-Object -FilterScript {

                                $psItem.Value -eq $ExpandedCurrent.Key.Id
                            }
                            
                            If
                            (
                                $ObjectWellKnownCurrent
                            )
                            {
                                $PropertyCurrent += @{

                                    Label      = 'Well-Known Object'
                                    Expression = {
                                        $ObjectWellKnownCurrent.key -join ','
                                    }
                                }
                            }
    
                         <# Each element gets added as a property, but only for
                            existing elements. We cannot build universal list of
                            properties which applies for all objects because they
                            will have different elements. Hence each object gets
                            processed individually  #>

                            $ExpandedCurrent.Value | ForEach-Object -Process {

                                [System.String]$Label = $psItem.Type

                             <# Building “Expression” for property value. This
                                is a little tricky because we need to expand the
                               “Label” variable into actual property name, but
                                keep the rest of the variables as raw text.
                               (They will be expanded at the time when
                                expression runs)
                              #>

                             <# $StringBuilder =
                                    [System.Text.StringBuilder]::New()
                                
                                [System.Void]( $StringBuilder.Append(
                                    '$ValueCurrent =  $psItem.Value |'
                                ))
                                [System.Void]( $StringBuilder.Append(
                                    ' Where-Object -FilterScript {'
                                ))
                                [System.Void]( $StringBuilder.Append( "`n" ))
                                [System.Void]( $StringBuilder.Append(
                                    '    $psItem.Type -eq '''
                                ))
                                [System.Void]( $StringBuilder.Append( $Label ))
                                [System.Void]( $StringBuilder.Append( "'`n"  ))
                                [System.Void]( $StringBuilder.Append( "}`n"  ))
                                [System.Void]( $StringBuilder.Append( "`n"   ))
                                [System.Void]( $StringBuilder.Append( '$ValueCurrent.Value' ))
                            
                                $ScriptBlock =
                                    [System.Management.Automation.ScriptBlock]::Create( 
                            
                                        $StringBuilder.ToString()
                                    )  #>

                                $Expression  = [System.String]::Empty
                                $Expression += '$ValueCurrent =  $psItem.Value |'
                                $Expression += ' Where-Object -FilterScript {'
                                $Expression += "`n"
                                $Expression += '    $psItem.Type -eq '''
                                $Expression += $Label
                                $Expression += "'`n"
                                $Expression += "}`n"
                                $Expression += "`n"
                                $Expression += '$ValueCurrent.Value'
                            
                                $ScriptBlock =
                                    [System.Management.Automation.ScriptBlock]::Create(                            
                                        $Expression
                                    )

                                $PropertyCurrent += @{

                                    Label      = $Label
                                    Expression = $ScriptBlock                                
                                }                            
                            }

                            $ExpandedCurrent |
                                Select-Object -Property $PropertyCurrent
                        }

                   #endregion Format

                    Return $Formatted
                }
                Else
                {
                    Return $Expanded
                }                 
            }
            Else
            {
                $Message = "Returning $(@($Raw).count) objects"
                
                If
                (
                    $Raw
                )
                {
                    [ObjectType[]]$TypeCurrent = $Raw.Type | Sort-Object -Unique
                    $Message += " of type $TypeCurrent"
                }
                Write-Debug -Message $Message

                $Raw | ForEach-Object -Process {

                    $Message = "  * $($psItem.id)"
                    Write-Debug -Message $Message
                }

                Return $Raw
            }

       #endregion Process (Expand and Format)
    }
}