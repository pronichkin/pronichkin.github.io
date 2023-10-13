 <#
    54. Returning an object

    Althoug we did return an object (of type “System.int32”) before, it was not
    very illustrative.

    Now, let's run the same code and return the output at the same time.

    We knew that MessageBox.show() is returning an object of type
   “System.Windows.Forms.DialogResult” all along. But previously, we've been
    casting it to void, i.e. swallowing instead of using it.

    Now let's replace void with actual return type (DialogResult) so that it gets
    returned from our method.

    We would also need to prepend “return” keyword to method execution, because
    it does not happen by default (unlike in PowerShell.)
  #>

$path = '.\54.cs'

Get-Content -Path $path

$TypeParam = @{
    Path                 = $path
    ReferencedAssemblies = 'System.Windows.Forms.dll'
}
Add-Type @TypeParam

 <# 
    Now we've created another type, named “Pronichkin.Sample.myType53”

    It has a method that accepts output. What this method does is displaying a
    message box with the provided text.

    And after running our method, we'll see the returned object.
  #>

[Pronichkin.Sample.myType54]::myMethod( 'This is a new message!' )

 <#
    At this point, our custom method works the same way as the .NET method on
    step 1. It does accept parameters at input, and it does emit output.

    Excep that we did it from our own c# source file instead of just calling the
    same .NET method directly from PowerShell.
  #>