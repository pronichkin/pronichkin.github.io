Function
Get-bcdStore
{
 <#
   .SYNOPSIS
    Opens existing BCD store

   .DESCRIPTION
    <to do>
  #>

    [OutputType(
        'Microsoft.Management.Infrastructure.CimInstance#ROOT/WMI/BcdStore'
    )]

    [CmdletBinding()]
        
    Param(
        [Parameter(
            Mandatory         = $False,
            ValueFromPipeline = $True
        )]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]
        $File
    ,
        [Parameter(
            Mandatory = $False
        )]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.cimSession]
        $cimSession
    )

    Process
    {
        If
        (
            $File
        )
        {
         <# WMI format:
            \??\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd
            File system format:
            \\?\Volume{9e51bc72-1be1-47ea-ab5c-8e30acc6a0bf}\efi\microsoft\boot\bcd

            Because we obtained path from a PowerShell file system object and
            will use it in a WMI method, we need to convert from the latter 
            into the former
            
            Note that it won't be needed if the path is rooted to a drive letter
          #>

            $Path = $File.FullName.Replace( '\\?\', '\??\' )

            $Message = "Opening BCD Store from `“$Path`”"
            Write-Debug -Message $Message
        }
        Else
        {
            $Path = [System.String]::Empty

            $Message = 'Opening the system default BCD Store'
            Write-Debug -Message $Message
        }

        $ClassParam = @{

            ClassName = 'BcdStore'
            Namespace = 'root\wmi'
            Verbose   = $False
        }

        If
        (
            $CimSession
        )
        {
            $ClassParam.Add( 'CimSession', $CimSession )
        }

      # Link

        $BcdStore = Get-cimClass @ClassParam

        $Argument = @{ 'File' = $Path }

     <# The CreateStore, OpenStore, and ImportStore methods are static methods; 
        they can be called without an instance of the class. To do so, open a
        WMI object that represents the BcdStore class and call these methods  #>

        $MethodParam = @{
    
            CimClass   = $BcdStore
            MethodName = 'OpenStore'
            Arguments  = $Argument
            Verbose    = $False    
        }
        $OpenStore = Invoke-CimMethod @MethodParam

        If
        (
            $OpenStore.ReturnValue
        )
        {
            Return $OpenStore.Store
        }
        Else
        {
            Throw
        }
    }
}