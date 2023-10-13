namespace Pronichkin.Sample
{
    public class myType53
    {    
        public static void myMethod(
            System.Int32 myInput
        )
        {
            System.Int32  myResult = myInput + 2;
            System.String myString = myResult.ToString();

         // https://docs.microsoft.com/dotnet/api/system.windows.forms.messagebox
            System.Windows.Forms.MessageBox.Show( myString );
        }
    }
}