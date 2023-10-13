 <#
    2. Writing arbitrary code

    But let's now imagine you want to do something more complex. Something that
    is not available natively in PowerShell like what we did previously.

    if you cannot do something natively in PowerShell, your next best bet is to
    find a .NET class and method to do it. But what if that was not an option
    either?

    The next best option is to do it in c#. After all, c# is .NET, and .NET is
    natively integrated in PowerShell. So that you can do things like passing
    objects back and forth.

    First, we have to learn how to call c# code from PowerShell. However, even
    before we write some code, we need to answer two questions.

    The first question is where we place the code. Because it's not a PowerShell
    code, we need to “hide” or abstract it from PowerShell. So that PowerShell
    does not treat it as its own code and try to execute it rigth away. (Whcih
    it won't be able to because the syntax is slightly different.) To do so, we
    put the code in a here string.
    
    Here sting is basically a free form block of plain text. PowerShell has no
    idea what's there. There are no rules, no parsing, no code formatting.
    
    Even though PowerShell does not understand it, our code has to follow c#
    syntax. To start with, let's learn that in c#, what starts with “//” is a
    comment.
  #>

$Code = @'

    // we will add some code here
'@

 <#
    So far, you can store the code in a variable and read it as plain text. That's a start.
  #>

$Code