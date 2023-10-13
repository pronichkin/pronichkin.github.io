Function
ConvertFrom-StringXml
{
 <#
   .SYNOPSIS
        De-serialize raw XML commonly found in properties of Hyper-V CIM objects
        and only return the element named “Instance”
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [System.Management.Automation.OutputTypeAttribute(
        [System.Xml.XmlElement]
    )]

    Param
    (
        [System.Management.Automation.AliasAttribute( 'String' )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.String]
        $InputObject
    )
        
    Process
    {
        $xml = [System.Xml.XmlDocument]::new()
        $xml.LoadXml( $InputObject )

        $psCmdlet.WriteObject( $xml.Instance )
    }
}