<#
.Synopsis
Lists PInvoke functions that loaded assemblies have declared.

Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

.DESCRIPTION
Lists PInvoke functions that loaded assemblies have declared. Useful for 
identifying native functions that have already been PInvoked so you don't have
to do it again via reflection.  .NET 2.0 port of the code found in Matt 
Graeber's blog post (http://www.exploit-monday.com/2012/12/list-all-win32native-functions.html)

.EXAMPLE
Get-LoadedPInvokeFunctions | Out-GridView

#>
function Get-LoadedPInvokeFunctions
{
    $Assemblies = [AppDomain]::CurrentDomain.GetAssemblies()
    $Attr = @()
    foreach($assembly in $Assemblies)
    {
        $Types = $assembly.GetTypes()
        
        foreach($Type in $Types)
        {
            $Methods = $Type.GetMethods('NonPublic, Public, Static, Instance')
            
            foreach($Method in $Methods)
            {
                if($Method.Attributes -band [Reflection.MethodAttributes]::PinvokeImpl)
                {
                    $Method.GetCustomAttributes($Method) | 
                    ? { $_.TypeId -eq [System.Runtime.InteropServices.DllImportAttribute] } | 
                    ? { $_.ConstructorArguments.Value -ne 'QCall' } |
                    % {   
                        New-Object PSObject -Property @{ 
                            Dll = $_.Value; 
                            Name = $Method.Name; 
                            DeclaringType = $Method.DeclaringType 
                        } 
                      }
                }
            }
        }
    } 
}
