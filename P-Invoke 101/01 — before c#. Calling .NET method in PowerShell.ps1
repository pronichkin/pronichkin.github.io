 <#
    # 1. Calling .NET methods in PowerShell
    
    Let's say you want to show a message box. In fact, that's pretty easy. There's a .NET method for that. It's literally called “MessageBox”, and it has a method called “Show”.

    And PowerShell can call .NET natively. In fact, I always thought that a better name for PowerShell would have been somethign like “.NET script” or “C-script”.

    After all, we did have JavaScript and VBScript, right?

    In our case, Show is a *static* method which means it can be used from the class itself. You do not need a class instance (your own object) to use this method.

    So, you just refer to the class, preferably by its full name, and then specify the method name and provide arguments in braces.    
  #>

# https://docs.microsoft.com/dotnet/api/system.windows.forms.messagebox
[System.Windows.Forms.MessageBox]::Show( 'This is the message' )

 <#
    Note that by default, this will generate a box with a single OK button.
    You can customize that by passing a third parameter to the method.
    In fact, there's quite a few options. But you cannot get rid of buttons
    altogether, in case you were thinking about that.

    Moreover, this will return “OK” after you close the window. Because OK is what you clicked
    and it's kinda important to know that. (Especially if there were multiple buttons to chose from.)

    The OK is actually not a string but an object of type “System.Windows.Forms.DialogResult”

    If you don't want any output, you can void it, of course. But that's a different story.    
  #>

[System.Void][System.Windows.Forms.MessageBox]::Show( 'This is the message' )