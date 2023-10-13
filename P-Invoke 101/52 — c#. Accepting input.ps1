 <#
    52. Accepting input

    Let's continue making our code more useful. What if instead of adding pre
   -defined values, we could accept one as an input?

    to do that, we need to add a new variable as parameter.

    To describe a parameter, we first add it into the method defintion, by
    specifying both type and variable name, where we used to have the empty
    braces.
    
    And then we use the variable inside the code.
  #>

$path = '.\52.cs'

Get-Content -Path $path

$TypeParam = @{
    Path           = $path
}
Add-Type @TypeParam

 <# 
    Now we've created another type, named “Pronichkin.Sample.myType52”

    When we run this code, now we have to specify the parameter. Unlike in PowerShell, the parameters are always unnamed.

   .NET relies on the order of parameters to tell one from another. Right now, when we have just one parameter, this is simple.
  #>

[Pronichkin.Sample.myType52]::myMethod( 3 )