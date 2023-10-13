Function
ConvertFrom-XmlInstance
{
 <#
   .SYNOPSIS
        Convert XML element to dictionary that only contains the values of nodes
        named “Property.” If the instance has multiple nodes with this name, a
        single dictionary will be emitted. If multiple instances are supplied
        by pipe, this will result in multiple dictionaries.
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Collections.Generic.Dictionary[
            System.String,
            System.String
        ]]
    )]

    Param
    (
        [System.Management.Automation.AliasAttribute( 'Instance' )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Xml.XmlElement]
        $InputObject
    )

    Begin
    {
      # Find the root module of which the current module is loaded as nested
      # This will be needed to run non-exported functions from this module
        $Module = Get-Module | Where-Object -FilterScript {
            $ExecutionContext.SessionState.Module -in $psItem.NestedModules
        }
    }

    Process
    {
        $Dictionary = & $Module {
            $Args[0] | Expand-XmlElement
        } $InputObject.Property

        $psCmdlet.WriteObject( $Dictionary )
    }
}