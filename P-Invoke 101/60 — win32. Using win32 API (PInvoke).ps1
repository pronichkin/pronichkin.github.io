 <#
    60. Using win32 API (P/Invoke)

    All the previous examples were purely synthetical. In real world, if all you
    want is to run some .NET methods (such as “MessageBox.show()”) in PowerShell,
    you rarely need to write c# code for it. This is because PowerShell can use
   .NET types natively, without using c# syntax. In fact, we demonstrated exactly
    that in the very first example in this tutorial.

    But what if we need to do something not natively available in .NET?

    Unlike PowerShell, c# can call platform native, win32 API. It is done via a
    mechanism called “Platform Invoke” or “P/Invoke” for short.

    For simplicity, let's pretend that Windows Forms did not have a Message Box
    functionality. So that we have to use a similar feature from Win32 API.

    Here, we still don't need to author any real code to do the work (since it's
    already available in the “native”, win32 DLL.) However, what we do need is to
    declare the method so that it becomes available in c# code. And, subseuqnetly,
    in the type made available to PowerShell.

    We could run DllImport in PowerShell natively, like this
    
    [System.Runtime.InteropServices.DllImportAttribute]::new( 'user32.dll' )

    However, it's not possible to define a method in such a way that it refers to
    a native platform function in PowerShell.

    Hence, we have to do this in c# syntax and use Add-Type for it.
  #>

$path = '.\60.cs'

Get-Content -Path $path

 <#
    The declaration has a new keyword that you can notice, extern, which tells
    the runtime this is an external method, and that when you invoke it, the
    runtime should find it in the DLL specified in DllImport attribute.
  #>

$TypeParam = @{
    Path                 = $path
}
Add-Type @TypeParam

 <#
    Now, when calling the method, we need to refer to it by its name, and then
    provide parameters as order, as expected by method definiton
  #>

[Pronichkin.Sample.myType60]::MessageBox(
    [System.IntPtr]::Zero,  # A handle to the owner window of the message box to be created
    'my message',           # The message to be displayed
    'my title',             # The dialog box title
    0                       # The contents and behavior of the dialog box
)