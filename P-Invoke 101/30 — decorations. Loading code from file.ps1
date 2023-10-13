 <#
    24. Loading code from a file

    We've just learned that what “Add-Type” does is compiling some code into .NET
    library or assembly. But so far, we only provided the source code inline,
    within the same PowerShell script. This may look handy at first sight, but it
    makes it difficult to write c# code because there's no sytax highlighting and
    no other IDE support. It may also make your PowerShell files too long and
    complex to understand.

    As a general practice, c# code should reside in a dedicated file with “.cs”
    file extension. This way, when needed, you can load it into an IDE which
    supports c# syntax and edit it separately from your PowerShell script.
    Moreover, this will allow you to refer to the same code file from multiple
    different scripts. Let's do it, although for our tiny useless bit of code
    this might initially look as an instant overkill.

   “Add-Type” is still the way to go. It has an option just for this: “-Path”. It
    lets you specify a path to the source file, which in our case will contain
    the c# code.

    However, in this case, we cannot use the simplified, implicit member definition.
    We should always use the more explicit type definition. The code we used on
    the previous step will do. Let's just save it to a file, say, “06.cs”
  #>

$path = '.\30.cs'

Get-Content -Path $path

 <#
    what we now have is the minial viable decoration to house our future c# code.
    It is basically an equivalent of what “Add-Type” did when we provided no code
    at all to it and asked it to create a class automatically from it, by using
    the “from member definition” mode. But unlike using this mode, we can now
    load the code from an external source file. And the net effect is still the
    same. We have a pretty much empty class which is public and has one
    constructor.
#>

$TypeParam = @{
    Path     = $path
}
Add-Type @TypeParam
 
[Pronichkin.Sample.myType30].IsPublic

[Pronichkin.Sample.myType30].DeclaredMembers

$myInstance30 = [Pronichkin.Sample.myType30]::new()