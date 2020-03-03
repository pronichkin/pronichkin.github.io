using module '.\ObjectType.psm1'
using module '.\ObjectWellKnown.psm1'

Function
Get-bcdObject
{
    [OutputType(
        'Microsoft.Management.Infrastructure.CimInstance#ROOT/WMI/BcdObject'
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
            'Microsoft.Management.Infrastructure.CimInstance#ROOT/WMI/BcdStore'
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
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
                $ObjectWellKnown.Values
            }
        )]
        [ValidateScript(
            {
                $psItem -in $ObjectWellKnown.Values
            }
        )]
        [System.String]
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
      # manual navigation via child objects

        [Parameter(
            Mandatory = $False
        )]
        [System.Management.Automation.SwitchParameter]
        $Format
    )

 <# DynamicParam
    {
        $Attribute = [System.Management.Automation.ParameterAttribute]::new()

        $Attribute.ParameterSetName = [System.Management.Automation.ParameterAttribute]::AllParameterSets
        $Attribute.Mandatory        = $False

        $AttributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
        $AttributeCollection.Add( $Attribute )

        $Value = [System.Collections.Generic.List[System.String]]::new()
        $Value.Add( 'blah1' )
        $Value.Add( 'blah2' )
        $Value.Add( 'blah3' )

        $ValidateSet = [System.Management.Automation.ValidateSetAttribute]::new( $Value )
                
        $AttributeCollection.Add( $ValidateSet )

        $Parameter = [System.Management.Automation.RuntimeDefinedParameter]::new( 'WellKnownID', [System.String], $AttributeCollection )
        $ParameterDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $ParameterDictionary.Add( 'WellKnownID', $Parameter )

        Return $ParameterDictionary
    }  #>

    Process
    {
       #region Raw (basic API call)

            If
            (
                $WellKnownID
            )
            {
                $Message = "Well-Known ID: $WellKnownID"                
            }
            Else
            {
                $Message = 'No Well-Known ID was provided'
            }
            Write-Verbose -Message $Message

            If
            (
               -Not $Store
            )
            {
                $Store = Get-bcdStore
            }

            $MethodParam = @{
        
                CimInstance = $Store
                Verbose     = $False
            }

            Switch
            (
                $psCmdlet.ParameterSetName
            )
            {
                'Type'
                {
                    If
                    (
                        @( $Type ).Count -eq 1
                    )
                    {
                        $Message = "Enumerating BCD objects of type `“$Type`”"
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

                'Id'
                {
                    If
                    (
                        @( $Id ).Count -eq 1
                    )
                    {
                        $Message = "Retrieving BCD object with ID `“$Id`”"
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

                'List'
                {
                    $Message = "Type or ID were not specified. Listing all BCD objects in store `“$Store`”"
                    Write-Debug -Message $Message

                    $Raw = [ObjectType].GetEnumValues() | ForEach-Object -Process {

                        Get-bcdObject -Store $Store -Type $psItem
                    } #| Sort-Object -Unique -Property 'Id'
                }

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
                        Throw
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

                        $IdEx.Add( 'Id'        ,  [System.Guid] $ObjectCurrent.Id   )
                        $IdEx.Add( 'Type'      ,  [ObjectType]  $ObjectCurrent.Type )
                  
                        $ElementParam = @{

                            Object = $psItem
                            Expand = $Expand
                            Format = $Format
                        }
                        $Element = Get-bcdObjectElement @ElementParam
                    
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
                    
                        $Formatted = $Expanded.GetEnumerator() | ForEach-Object -Process { 

                            $ExpandedCurrent = $psItem

                         <# Clone the list of proeperties so that we can append
                            it with the properties which are specific for the
                            curren object  #>

                            $PropertyCurrent = $Property

                         <# A property to specify a well-known object ID, if 
                            applicable  #>

                            $ObjectWellKnownCurrent = $ObjectWellKnown[ $ExpandedCurrent.Key.Id ]

                            If
                            (
                                $ObjectWellKnownCurrent
                            )
                            {
                                $PropertyCurrent += @{

                                    Label      = 'Well-Knonw Object'
                                    Expression = { $ObjectWellKnownCurrent }
                                }
                            }
    
                         <# Each element gets added as a property, but only for
                            existing elements. We cannot build universal list of
                            properties which applis for all objects because they
                            will have different elements. Hence each object gets
                            processed individually  #>

                            $ExpandedCurrent.Value | ForEach-Object -Process {

                                [System.String]$Label = $psItem.Type

                                $StringBuilder = [System.Text.StringBuilder]::New()

                             <# Building “Expression” for property value. This
                                is a little tricky because we need to expand the
                               “Label” variable into actualy property name, but
                                keep the rest of the variables as raw text.
                               (They will be expanded at the time when
                                expression runs)
                              #>

                                [System.Void]( $StringBuilder.Append( '$ValueCurrent =  $psItem.Value | Where-Object -FilterScript {' ) )
                                [System.Void]( $StringBuilder.Append( "`n" ))
                                [System.Void]( $StringBuilder.Append( '    $psItem.Type -eq ''' ))
                                [System.Void]( $StringBuilder.Append( $Label ) )
                                [System.Void]( $StringBuilder.Append( "'`n" ))
                                [System.Void]( $StringBuilder.Append( "}`n" ))
                                [System.Void]( $StringBuilder.Append( "`n" ))
                                [System.Void]( $StringBuilder.Append( '$ValueCurrent.Value' ))
                            
                                $ScriptBlock = [System.Management.Automation.ScriptBlock]::Create( 
                            
                                    $StringBuilder.ToString()
                                )

                                $PropertyCurrent += @{

                                    Label      = $Label
                                    Expression = $ScriptBlock                                
                                }                            
                            }

                            $ExpandedCurrent | Select-Object -Property $PropertyCurrent
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
                $Message = "Returning $($Raw.count) objects"
                
                If
                (
                    $Raw
                )
                {
                    $Message += " of type $([ObjectType[]]$Raw.Type | Sort-Object -Unique)"
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