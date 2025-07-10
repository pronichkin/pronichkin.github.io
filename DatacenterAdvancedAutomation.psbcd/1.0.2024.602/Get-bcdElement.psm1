using Module '.\ElementType.psm1'
using Module '.\Flag.psm1'
using Module '.\DeviceType.psm1'

Function
Get-bcdElement
{
    [System.Management.Automation.CmdletBindingAttribute(
        HelpURI           = 'https://pronichkin.com',
        PositionalBinding = $false
    )]

    param(
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $true,
            HelpMessage       = 'https://learn.microsoft.com/previous-versions/windows/desktop/bcd/bcdObject',
            ValueFromPipeline = $true
        )]
        [System.Management.Automation.AliasAttribute(
            'Object'
        )]
        [System.Management.Automation.psTypeNameAttribute(
            'Microsoft.Management.Infrastructure.CimInstance#root/wmi/bcdObject'
        )]
        [Microsoft.Management.Infrastructure.CimInstance]
        $InputObject
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
        [ElementType]
        $Type
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false
        )]
      # [Flag]
        [BCD_FLAGS_TYPE]
        $Flag
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            HelpMessage       = 'Expand known values, recursively, and add helpful metadata'
        )]
        [System.Management.Automation.SwitchParameter]
        $Expand
    ,
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $false,
            HelpMessage       = 'Format for human-readable output'
        )]
        [System.Management.Automation.SwitchParameter]
        $Format
    )

    begin
    {
        $message = "Retreiving elements for Object $($InputObject.Id)"
        Write-Debug -Message $message
        
        if
        (
            $InputObject.StoreFilePath
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

            if
            (
                $InputObject.StoreFilePath.Contains( [System.IO.Path]::VolumeSeparatorChar )
            )
            {
                $path = $InputObject.StoreFilePath.Replace( '\??\', [System.String]::Empty )
            }
            else
            {
                $path  = $InputObject.StoreFilePath.Replace( '\??\', '\\?\' )
              # $path  = $InputObject.StoreFilePath.Replace( '\??\', '\\.\' )
            }

            $item  = Get-Item -Path $path
            $store = Get-bcdStore -File $item
        }
        else
        {
            $store = Get-bcdStore
        }
    }

    process
    {
       #region Raw (basic API call)

            $methodParam = @{
                InputObject = $InputObject
                MethodName  = 'EnumerateElements'
                Verbose     = $false
            }
            $element = Invoke-CimMethod @methodParam

            if
            (
                $Type
            )
            {
                if
                (
                    $Type -in $element.Elements.Type
                )
                {
                    $methodParam = @{
                        InputObject = $InputObject
                        Verbose     = $false
                    }

                    $argument = @{
                        'Type' = $Type
                    }

                    if
                    (
                        $Flag
                    )
                    {
                        $argument.Add(    'Flags'      ,  $Flag                 )
                        $methodParam.Add( 'MethodName' ,  'GetElementWithFlags' )
                    }
                    else
                    {
                        $methodParam.Add( 'MethodName', 'GetElement'            )
                    }

                    $methodParam.Add( 'Arguments',  $argument                   )

                    $element = Invoke-CimMethod @methodParam

                    if
                    (
                        $element.ReturnValue
                    )
                    {
                        $raw = $element.Element
                    }
                    else
                    {
                        throw
                    }
                }
                else
                {
                    $message = 'Specified element type is not available on Object $($InputObject[0].Id)'
                    Write-Verbose -Message $message
                }
            }
            else
            {
                $message = "Type was not specified, listing all elements of Object $($InputObject[0].Id)"
                Write-Debug -Message $message

                if
                (
                    $element.ReturnValue
                )
                {
                    $raw = $element.Elements
                }
                else
                {
                    throw
                }
            }

       #endregion Raw (basic API call)

       #region Process (Expand and Format)

            if
            (
                $Expand -or
                $Format
            )
            {
               #region Expand

                    $expanded = [System.Collections.Generic.Dictionary[
                   
                      # “TypeEx” describes Type and associated Format
                        System.Collections.Generic.Dictionary[
                            System.String, System.Object
                    
                      # Value which can be of various types
                        ], System.Object
                    ]]::New()

                    $raw | ForEach-Object -Process {
        
                        $elementCurrent = $psItem

                        $typeEx = [System.Collections.Generic.Dictionary[
                            System.String, System.Object
                        ]]::new()
                    
                        $typeEx.Add( 'Type'    ,  [ElementType]   $elementCurrent.Type                  )
                        $typeEx.Add( 'Format'  ,  [System.String] $elementCurrent.CimClass.CimClassName )

                      # Different handling depending on Element format
                      # https://docs.microsoft.com/previous-versions/windows/desktop/bcd/bcd-classes

                        switch
                        (
                            $elementCurrent.CimClass.CimClassName
                        )
                        {
                            'BcdStringElement'
                            {
                                $value = $elementCurrent.String
                            }

                            'BcdDeviceElement'
                            {
                                $elementParam = @{

                                    Element = $elementCurrent
                                    Expand  = $Expand
                                    Format  = $Format
                                }
                                $value = Get-bcdElementDevice @elementParam
                            }

                            'BcdObjectListElement'
                            {
                                $objectPartam = @{
                                    Store  = $store
                                    Id     = $elementCurrent.Ids
                                    Expand = $Expand
                                    Format = $Format
                                }
                                $value = Get-bcdObject @objectPartam
                            }

                            'BcdBooleanElement'
                            {
                                $value = $elementCurrent.Boolean
                            }

                            'BcdIntegerListElement'
                            {
                                $value = $elementCurrent.Integers
                            }

                            'BcdIntegerElement'
                            {
                                $value = $elementCurrent.Integer
                            }

                            'BcdObjectElement'
                            {
                                $objectPartam = @{
                                    Store  = $store
                                    Id     = $elementCurrent.Id
                                    Expand = $Expand
                                    Format = $Format
                                }
                                $value = Get-bcdObject @objectPartam
                            }

                            Default
                            {
                                $value = "(Unknown value type `“$psItem`”)"
                            }
                        }

                        $expanded.Add( $typeEx, $value )
                    }
                
               #endregion Expand

                If
                (
                    $Format
                )
                {
                   #region Format

                        $property = @(

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

                        $formatted = $expanded.GetEnumerator() | Select-Object -Property $property

                   #endregion Format
                    
                    Return $formatted
                }
                Else
                {
                    Return $expanded
                }                 
            }
            else
            {
                return $raw
            }

       #endregion Process (Expand and Format)
    }

    end
    {}
}