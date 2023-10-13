  # Does not work

  # Import-Module -name 'Get-myA.psm1'
  # Import-Module -name 'Get-myB.psm1'

  # Still does not work

  # Import-Module -name '.\Get-myA.psm1'
  # Import-Module -name '.\Get-myB.psm1'

  # Works

    Import-Module -name "$psScriptRoot\Get-myA.psm1"
    Import-Module -name "$psScriptRoot\Get-myB.psm1"