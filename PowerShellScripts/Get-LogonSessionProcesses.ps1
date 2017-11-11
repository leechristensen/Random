<#
Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

Example:

Gets all processes started in a logon session with a logon type of 9 (NewCredential)
Useful for identifying processes started with "runas.exe /netonly" or using Mimikat'z sekurlsa::pth capability

$a = Get-LogonSession -LogonType 9 | select -ExpandProperty LogonId; 
Get-LogonSessionProcesses $a

#>

function Get-LogonSession
{
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [int]
        $Type
    )

    if($Type) {
        Get-WmiObject Win32_LogonSession -Filter "LogonType=$Type" 
    } else {
        Get-WmiObject Win32_LogonSession
    }
}


function Get-LogonSessionProcesses
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [int[]]
        $Id
    )
  
    foreach($Id in $LogonId)
    {
        Get-WmiObject -Query ("ASSOCIATORS OF {Win32_LogonSession.LogonId=$Id} WHERE ResultClass = Win32_Process")
    }
}
