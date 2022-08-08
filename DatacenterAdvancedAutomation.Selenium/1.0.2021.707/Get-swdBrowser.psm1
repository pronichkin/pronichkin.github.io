Set-StrictMode -Version 'Latest'

Function
Get-swdBrowser
{
 <#
       .Synopsis
        Obtain the binary for Edge web browser
  #>

    [System.Management.Automation.CmdletBindingAttribute()]

    [OutputType(
        [System.IO.FileInfo]
    )]

    Param
    (    
        [System.Management.Automation.ParameterAttribute(
            Mandatory = $True
        )]
        [System.Management.Automation.ValidateSetAttribute(
        
            'CurrentUser',
            'AllUsers'
        )]
        [System.String]
        $Scope
    )

    End
    {
        Switch
        (
            $Scope
        )
        {
            'CurrentUser'
            {
             <# Using the Browser which is installed per-user. Because the binary
                is located in user profile, it is writeable and we can put the
                driver there  #>

                $PathParam =  @{
            
                    Path      = $env:LocalAppData
                    ChildPath = 'Microsoft\Edge SxS\Application'
                }
            }

            'AllUsers'
            {
             <# Using the Browser which is installed per-system. Normal users do
                not have permissions to write there. Hence putting the driver into
                user temporary directory  #>

                $PathParam = @{
                
                    Path      = ${env:ProgramFiles(x86)}
                    ChildPath = 'Microsoft\Edge\Application'
                }                
            }
        }

        $Path = Join-Path @PathParam

        Return Get-ChildItem -Path $Path -Filter 'msedge.exe'
    }
}