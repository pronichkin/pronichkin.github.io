 <#
    50. Writing actual code to run

    Great, let's finally add some actual code to run in our method.

    Let's say it needs to sum 1 and 2.

    Note a couple of things which make c# syntax different from PowerShell.

 1. You cannot “just” run the arithmetic operation. You need to assign result to a variable.
 2. You cannot “just” start using a variable. You have to specify its type first time you mention it.
 3. Variable name does not start with $ or any other special decoration.
 4. You have to end each code string with a “;”

    Other than that, the code is pretty self-explanatory
  #>

$path = '.\50.cs'

Get-Content -Path $path

 <#
    Now, even though it's a valid c# code, it's obviously useless. We create a
    variable and assign a value to it, but never use it. PowerShell does not
    care about such neglectance, even if you enable Strict Mode. But in C#, the
    compiler would warn us about a potential mistake. And by default, “Add-Type”
    handles compiler warnings as errors. Hence we need to explicitly tell it not
    to.
  #>

$TypeParam = @{
    Path           = $path
    IgnoreWarnings = $True
}
Add-Type @TypeParam

 <# 
    Now we've created another type, named “Pronichkin.Sample.myType50”

    If we call our static method, we'll have the code run. It's hard to notice yet, because our code does not
    do any meaningful action and does not output anything. But trust me, the code runs. You can tell it from
    not having any errors or warnings.
  #>

[Pronichkin.Sample.myType50]::myMethod()