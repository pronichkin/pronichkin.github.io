    $Credential = Get-Credential

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

<# 4..5 | ForEach-Object -Process {
    $Name.Add( 'Kepler' + $psItem.ToString( 'D3' ) )
}  #>

<# 1..2 | ForEach-Object -Process {
    $Name.Add( 'ArtemP-HCI-' + $psItem.ToString( 'D2' ) )
}  #>

<# 3..4 | ForEach-Object -Process {
    $Name.Add( 'ArtemP-Test-' + $psItem.ToString( 'D2' ) )
}  #>

<# 2..3 | ForEach-Object -Process {
    $Name.Add( 'ArtemP-Test--' + $psItem.ToString( 'D2' ) )
}  #>

  # $Name.Add( 'ArtemP-hvs01c'  )
  # $Name.Add( 'ArtemP-hvs02f'  )
  # $Name.Add( 'ArtemP-hvs03p'  )

  # $Name.Add( 'ArtemP-rs5ru'   )
  # $Name.Add( 'ArtemP-rs5fr'   )
  # $Name.Add( 'ArtemP-rs5de'   )
  # $Name.Add( 'ArtemP-rs5it'   )
  # $Name.Add( 'ArtemP-rs5es1'  )
  # $Name.Add( 'ArtemP-rs5cn'   )
  # $Name.Add( 'ArtemP-rs5ja'   )

  # $Name.Add( 'ArtemP-rs1-01'  )
  # $Name.Add( 'ArtemP-rs5ja01' )
  # $Name.Add( 'ArtemP-rs5cl01' )
  # $Name.Add( 'ArtemP-rs5en01' )

  # $Name.Add( 'ArtemP-VMM-00'  )
  # $Name.Add( 'ArtemP-VMM-01'  )
  # $Name.Add( 'ArtemP-DB-00'   )

  # $Name.Add( 'Kepler003'      )
  # $Name.Add( 'Kepler004'      )
  # $Name.Add( 'Kepler005'      )

  # $Name.Add( 'ArtemP-HCI-03'  )
  # $Name.Add( 'ArtemP-HCI-05'  )
  # $Name.Add( 'ArtemP-HCI-06'  )
  # $Name.Add( 'ArtemP-HCI-07'  )
  # $Name.Add( 'ArtemP-HCI-08'  )
  # $Name.Add( 'ArtemP-HCI-09'  )
  # $Name.Add( 'ArtemP-HCI-25'  )
  # $Name.add( 'ArtemP-HCI-30'  )
  # $Name.add( 'ArtemP-HCI-31'  )
  # $Name.Add( 'ArtemP-HCI-32'  )
  # $Name.Add( 'ArtemP-HCI-33'  )
  # $Name.Add( 'ArtemP-HCI-34'  )
  # $Name.Add( 'ArtemP-HCI-35'  )
  # $Name.Add( 'ArtemP-HCI-36'  )
  # $Name.Add( 'ArtemP-HCI-37'  )
  # $Name.Add( 'ArtemP-HCI-44'  )
  # $Name.Add( 'ArtemP-HCI-45'  )
    $Name.Add( 'ArtemP27s'      )
  # $Name.Add( 'ArtemP-HCI-50'  )
  # $Name.Add( 'ArtemP-HCI-51'  )

Clear-DnsClientCache

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

    $TestParam = @{

        ComputerName  = $psItem
        CommonTCPPort = 'WinRM'
        Debug         = $False
        Verbose       = $False
        WarningAction = [System.Management.Automation.ActionPreference]::SilentlyContinue
    }
    $Test = Test-NetConnection @TestParam

    If
    (
        $Test.TcpTestSucceeded
    )
    {
        $SessionParam = @{

            ComputerName = $psItem
            Verbose      = $False
        }

        If
        (
            Test-Path -Path 'Variable:\Credential'
        )
        {
            $Message = 'Explicit credentials were specified'
            Write-Message -Channel Debug -Message $Message

         <# $ItemPath = 'wsMan:\Localhost\Client\TrustedHosts'

            $Item = Get-Item -Path $ItemPath

            If
            (
                $Item.Value -and
                $Item.Value -split ',' -contains $Address[0]
            )
            {
                $Message = "`“$($Address[0])`” is already a trusted host"
                Write-Message -Channel Debug -Message $Message
            }
            Else
            {
                $Message = "Adding `“$($Address[0])`” to trusted hosts"
                Write-Message -Channel Debug -Message $Message

                $Item = Set-Item -Path $ItemPath -Value $Address[0] -Concatenate -Force -PassThru
            }  #>

            Add-wsManTrustedHost -HostName $psItem

            $SessionParam.Add(
                'Credential',
                $Credential
            )

            $SessionParam.Add(
                'Authentication',
                [Microsoft.Management.Infrastructure.Options.PasswordAuthenticationMechanism]::Negotiate
            )
        }

        $cimSession.Add( ( New-cimSession @SessionParam ) )
        $psSession.Add(  ( New-psSession  @SessionParam ) )
    }
    Else
    {
        $Message = "$psItem is unreachable"
        Write-Warning -Message $Message
    }
}