 <#
    3. Compiling code (and getting a class, or type, from implicit member definition)

    Believe it or not, what we've just did was writing some c# code. Even though
    there's literally nothing happening there, there's some text marked as a
    comment, and therefore it's a syntaxically correct piece of c# code.
  #>

$Code = @'

    // we will add some code here
'@

 <#
    Let's keep it that simple for a now. Before we write some actual code, we
    need to learn about the transition paths between c# and PowerShell.
    
    The first question is how we refer to this code from PowerShell. Unlike code
    written in PowerShell, we cannot “just read” it, becase PowerShell does not
    interpret or understand c# code.

    Instead, we need to *compile* the code into a .NET assembly. The result will
    then be loaded into PowerShell as a new type, or class. And as we saw before,
    PowerShell does pretty good job leveraging .NET types natively.

    In other words, the c# code by itself is of no use for PowerShell. But once
    we compile it and get a type, that would become easy.

    The easiest way to do that is the “Add-Type” cmdlet. It does both things.
    Compiles the code into an assembly, and loads it into the current PowerShell
    session right away.
  #>

$TypeParam = @{

    Name                 = 'myType03'
    MemberDefinition     = $Code
}
Add-Type @TypeParam

 <# 
    The cmdlet did not out output anything. (We could override that if specified
   “-PassThru” parameter.) But since there were no errors returned, it is a good
    sign. It means that the code was actually read by c# compiler and an assmbly
    was created and loaded.
  #>