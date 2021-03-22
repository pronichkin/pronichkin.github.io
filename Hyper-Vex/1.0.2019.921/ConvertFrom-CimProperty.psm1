Function
ConvertFrom-CimProperty
{
 <#
   .SYNOPSIS
        Collapse a list of dictionaries with arbitrary names and values
        to a single dictionary by selecting only “Name” and “Data”
        properties from each dictionary and converting each pair to
        a single entry
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
        [System.Management.Automation.AliasAttribute( 'Property' )]
        [System.Management.Automation.ParameterAttribute(
            Mandatory         = $True,
            ValueFromPipeline = $True
        )]
        [System.Collections.Generic.Dictionary[
            System.String,
            System.String
        ]]
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
        $Dictionary.Add( $InputObject.Name, $InputObject.Data )
    }

    End
    {
        $psCmdlet.WriteObject( $Dictionary )
    }
}