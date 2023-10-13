 <#
    4. Loading code from a file

    We've just learned that what “Add-Type” does is compiling some code into .NET
    library or assembly. But so far, we only provided the source code inline,
    within the same PowerShell script. This may look handy at first sight, but it
    makes it difficult to write c# code because there's no sytax highlighting and
    no other IDE support. It may also make your PowerShell files too long and
    complex to understand.

    As a general practice, c# code should reside in a dedicated file with “.cs”
    file extension. This way, when needed, you can load it into an IDE which
    supports c# syntax and edit it separately from your PowerShell script. Let's
    do it, although for our tiny useless bit of code this might initially look
    as an instant overkill.

   “Add-Type” is still the way to go. It has an option just for this: “-Path”. It
    lets you specify a path to the source file, which in our case will contain
    the c# code.

    However, in this case, we cannot use 
  #>