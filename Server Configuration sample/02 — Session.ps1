$Name       = [System.Collections.Generic.List[
    System.String
]]::new()

$Record     = [System.Collections.Generic.List[
    Microsoft.DnsClient.Commands.DnsRecord
]]::new()

$Address    = [System.Collections.Generic.List[
    System.String
]]::new()

$cimSession = [System.Collections.Generic.List[
    Microsoft.Management.Infrastructure.CimSession
]]::new()

$psSession  = [System.Collections.Generic.List[
    System.Management.Automation.Runspaces.psSession
]]::new()

<# 1..3 | ForEach-Object -Process {
    $Name.Add( 'Kepler' + $psItem.ToString( 'D3' ) )
}  #>

<# 1..2 | ForEach-Object -Process {
    $Name.Add( 'ArtemP-HCI-' + $psItem.ToString( 'D2' ) )
}  #>

  # $Name.Add( 'ArtemP-hvs01c' )
  # $Name.Add( 'ArtemP-hvs02f' )

  # $Name.Add( 'ArtemP-rs5ru' )
  # $Name.Add( 'ArtemP-rs5fr' )
  # $Name.Add( 'ArtemP-rs5de' )
    $Name.Add( 'ArtemP-rs5it' )
    $Name.Add( 'ArtemP-rs5es1' )
    $Name.Add( 'ArtemP-rs5cn' )
    $Name.Add( 'ArtemP-rs5ja' )

$Name | ForEach-Object -Process {
    Resolve-DnsName -Name $psItem -Verbose:$False -Debug:$False | ForEach-Object -Process { 
        $Record.Add( $psItem )
    }
}

$Record | Where-Object -FilterScript {
    $psItem -is [Microsoft.DnsClient.Commands.DnsRecord_A]
} | Sort-Object -Unique -Property 'Name' | ForEach-Object -Process {
    $Address.Add( $psItem.Name )
}

$Address | ForEach-Object -Process {
    $cimSession.Add( ( New-cimSession -ComputerName $psItem -Verbose:$False ) )
    $psSession.Add(  ( New-psSession  -ComputerName $psItem ) )
}