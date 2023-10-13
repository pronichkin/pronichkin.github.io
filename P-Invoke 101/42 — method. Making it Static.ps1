 <#
    42. Making it static
    
    What we did so far makes perfect sense if we wanted to call the method
    in the context of the instance of the type. In other words, we might 
    have different instances with different values or context, and then 
    use the same method (as defined in type), and get different results based
    on the contents of the type instance.

    But this sounds like an overkill in our basic scenario. Wouldn't it be better
    if we could “just” run the method, without creating an instance of the type?

    Yes, and to do so, you have to define method as static. Static means its
    available from the class itself, not its instances.
  #>

$path = '.\42.cs'

Get-Content -Path $path

$TypeParam = @{
    Path     = $path
}
Add-Type @TypeParam

 <# 
    We have created “Pronichkin.Sample.myType42” type.

    Now if we explore its methods, we'll find our method again. This time, not only it's public, but it's also static.
  #>

[Pronichkin.Sample.myType42].DeclaredMethods[0].IsStatic

 <#
    What it means, we can now call it directly from the type itself, without creating an instance.

    The syntax to do so is silimiar to how we used the constructor before.
  #>
  
[Pronichkin.Sample.myType42]::myMethod()