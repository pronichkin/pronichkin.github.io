Using Module '.\ElementType.psm1'
Using Module '.\Flag.psm1'
Using Module '.\DeviceType.psm1'

Function
Get-bcdObjectElement
{
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $Object
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ElementType]
        $Type
    ,
        [Parameter(
            Mandatory = $False
        )]
        [Flag]
        $Flag
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
        $Message = "Retreiving elements for Object $($Object.Id)"
        Write-Debug -Message $Message
        
        If
        (
            $Object.StoreFilePath
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

            $Path  = $Object.StoreFilePath.Replace( '\??\', '\\?\' )
          # .Replace( '\??\', [System.String]::Empty )
            $Item  = Get-Item -Path $Path
            $Store = Get-bcdStore -File $Item
        }
        Else
        {
            $Store = Get-bcdStore
        }
    }

    Process
    {
       #region Raw (basic API call)

            $MethodParam = @{

                InputObject = $Object            
                MethodName  = 'EnumerateElements'
                Verbose     = $False
            }
            $Element = Invoke-CimMethod @MethodParam

            If
            (
                $Type
            )
            {
                If
                (
                    $Type -in $Element.Elements.Type
                )
                {
                    $MethodParam = @{

                        InputObject = $Object
                        Verbose     = $False
                    }

                    $Argument = @{

                        'Type' = $Type
                    }

                    If
                    (
                        $Flag
                    )
                    {
                        $Argument.Add(    'Flags'      ,  $Flag                 )
                        $MethodParam.Add( 'MethodName' ,  'GetElementWithFlags' )
                    }
                    Else
                    {
                        $MethodParam.Add( 'MethodName', 'GetElement'            )
                    }

                    $MethodParam.Add( 'Arguments',  $Argument                   )

                    $Element = Invoke-CimMethod @MethodParam

                    If
                    (
                        $Element.ReturnValue
                    )
                    {
                        $Raw = $Element.Element
                    }
                    Else
                    {
                        Throw
                    }
                }
                Else
                {
                    $Message = 'Specified element type is not available on Object $($Object[0].Id)'
                    Write-Verbose -Message $Message
                }
            }
            Else
            {
                $Message = "Type was not specified, listing all elements of Object $($Object[0].Id)"
                Write-Debug -Message $Message

                If
                (
                    $Element.ReturnValue
                )
                {
                    $Raw = $Element.Elements
                }
                Else
                {
                    Throw
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
                   
                      # “TypeEx” describes Type and associated Format
                        System.Collections.Generic.Dictionary[
                            System.String, System.Object
                    
                      # Value which can be of various types
                        ], System.Object
                    ]]::New()

                    $Raw | ForEach-Object -Process {
        
                        $ElementCurrent = $psItem

                        $TypeEx = [System.Collections.Generic.Dictionary[
                            System.String, System.Object
                        ]]::new()
                    
                        $TypeEx.Add( 'Type'    ,  [ElementType]   $ElementCurrent.Type                  )
                        $TypeEx.Add( 'Format'  ,  [System.String] $ElementCurrent.CimClass.CimClassName )

                      # https://docs.microsoft.com/en-us/previous-versions/windows/desktop/bcd/bcd-classes

                        Switch
                        (
                            $ElementCurrent.CimClass.CimClassName
                        )
                        {
                            'BcdStringElement'
                            {
                                $Value = $ElementCurrent.String
                            }

                            'BcdDeviceElement'
                            {
                                $ElementParam = @{

                                    Element = $ElementCurrent
                                    Expand  = $Expand
                                    Format  = $Format
                                }
                                $Value = Get-bcdObjectElementDevice @ElementParam
                            }

                            'BcdObjectListElement'
                            {
                                $ObjectPartam = @{

                                    Store  = $Store
                                    Id     = $ElementCurrent.Ids
                                    Expand = $Expand
                                    Format = $Format
                                }
                                $Value = Get-bcdObject @ObjectPartam
                            }

                            'BcdBooleanElement'
                            {
                                $Value = $ElementCurrent.Boolean
                            }

                            'BcdIntegerListElement'
                            {
                                $Value = $ElementCurrent.Integers
                            }

                            'BcdIntegerElement'
                            {
                                $Value = $ElementCurrent.Integer
                            }

                            'BcdObjectElement'
                            {
                                $ObjectPartam = @{

                                    Store  = $Store
                                    Id     = $ElementCurrent.Id
                                    Expand = $Expand
                                    Format = $Format
                                }
                                $Value = Get-bcdObject @ObjectPartam
                            }

                            Default
                            {
                                $Value = "(Unknown value type `“$psItem`”)"
                            }
                        }

                        $Expanded.Add( $TypeEx, $Value )
                    }
                
               #endregion Expand

                If
                (
                    $Format
                )
                {
                   #region Format

                        $Property = @(

                            @{
                                Label      = 'Type'
                                Expression = { $psItem.Key.Type }
                            }

                            @{
                                Label      = 'Type ID'
                                Expression = { $psItem.Key.Type.Value__ }
                            }

                            @{
                                Label      = 'Format'
                                Expression = {

                                    $psItem.Key.Format.Substring(

                                        3,
                                        $psItem.Key.Format.Length-10
                                    )
                                }
                            }

                            @{
                                Label      = 'Value'
                                Expression = { $psItem.Value }
                            }
                        )

                        $Formatted = $Expanded.GetEnumerator() | Select-Object -Property $Property

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
                Return $Raw
            }

       #endregion Process (Expand and Format)
    }
}