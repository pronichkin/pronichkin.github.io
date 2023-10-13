 <#
    51. Outputting the result

    Now, let's turn the useless code into slightly less useless one. Let's make it
    output something, like the result of the calculation.

    For that, we need two things.

 1. Replace “void” with the type of the object we expect to return. In our case, it would be “System.Int32” because that't the type of the variable we product.
 2. Add an explicit Return statement to our code. Unlike in PowerShell, just refering to the variable won't output its value.    
  #>

$path = '.\51.cs'

Get-Content -Path $path

 <#
    Finally, because our code now makes sense, we can remove the “IgnoreWarnings” parameter.
 #>

$TypeParam = @{
    Path           = $path
  # IgnoreWarnings = $True
}
Add-Type @TypeParam

 <# 
    Now we've created another type, named “Pronichkin.Sample.myType51”

    And if we run this code, it will output “3”. Which is a value of “System.Int32” type.
  #>

[Pronichkin.Sample.myType51]::myMethod()