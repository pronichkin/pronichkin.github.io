 <#
    53. Using existing .NET method inside our code

    Now let's do something more similar to a real program. What if,
    instead of returning the value, we wanted to dispaly it in a window?
    
    Fortunately, we don't have to interact with Windows in order to draw a window
    ourselves. This is where our MessageBox example from the very beginning comes
    helpful. We know that .NET already has a method for it, and we can natively
    call it from our c# code. We will call the method from our c# code and provide
    our variable as parameter to it.
    
    There's a small problem, however. MessageBox.Show() method expects parameter
    as a string.

    Our variable is an int32 so far. And unlike PowerShell, c# is not willing to
    convert variables implicitly.

    Hence we'll have to do it in our code.

    Finally, because we don't expect any more input, we can change the method
    definition back to void.
  #>

$path = '.\53.cs'

Get-Content -Path $path

 <#
    Because we leverage a different .NET class (MessageBox) hosted in a separate
    assembly, we need to tell the compiler where to look for it. In other words,
    we'll refer to the assembly.
  #>
 
$TypeParam = @{
    Path                 = $path
    ReferencedAssemblies = 'System.Windows.Forms.dll'
}
Add-Type @TypeParam

 <# 
    Now we've created another type, named “Pronichkin.Sample.myType53”

    When we run our method, the message box will pop up. The message text will be the result of calculation.
  #>

[Pronichkin.Sample.myType53]::myMethod( 3 )