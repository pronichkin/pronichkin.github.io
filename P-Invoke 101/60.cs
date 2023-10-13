namespace Pronichkin.Sample
{
    public class myType60
    {    
     // Indicates that the attributed method is exposed by an unmanaged
     // dynamic-link library (DLL) as a static entry point.
     // https://docs.microsoft.com/dotnet/api/system.runtime.interopservices.dllimportattribute
        [System.Runtime.InteropServices.DllImportAttribute(
            "user32.dll"
        )]

     // Mark the method with public, static and extern modifiers.
     // https://docs.microsoft.com/windows/win32/api/winuser/nf-winuser-messagebox
        public static extern void MessageBox(
            System.IntPtr  hWnd,       // A handle to the owner window of the message box to be created
            string         lpText,     // The message to be displayed
            string         lpCaption,  // The dialog box title
            uint           uType       // The contents and behavior of the dialog box
        );
    }
}