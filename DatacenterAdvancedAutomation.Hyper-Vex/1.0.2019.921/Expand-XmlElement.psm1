Function
Expand-XmlElement
{
 <#
   .SYNOPSIS
        Convert from an XML element to a dictionary. If multiple elements are
        supplied by pipe, a single dictionary will be emitted
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
        [System.Management.Automation.AliasAttribute( 'Element' )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Xml.XmlElement]
        $InputObject
    )

    Begin
    {
        $Dictionary = [System.Collections.Generic.Dictionary[
            System.String,
            System.String
        ]]::new()
    }

    Process
    {
        $Dictionary.Add( $InputObject.Name, $InputObject.Value )
    }

    End
    {
        $psCmdlet.WriteObject( $Dictionary )
    }
}