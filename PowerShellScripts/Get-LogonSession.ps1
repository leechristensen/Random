<#
Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None
#>

function Get-LogonSession
{
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [string[]]
        $ComputerName = 'localhost'
    )

    $LogonMap = @{}
    Get-WmiObject -ComputerName $ComputerName -Class Win32_LoggedOnUser  | %{
    
        $Identity = $_.Antecedent | Select-String 'Domain="(.*)",Name="(.*)"'
        $LogonSession = $_.Dependent | Select-String 'LogonId="(\d+)"'

        $LogonMap[$LogonSession.Matches[0].Groups[1].Value] = New-Object PSObject -Property @{
            Domain = $Identity.Matches[0].Groups[1].Value
            UserName = $Identity.Matches[0].Groups[2].Value
        }
    }

    Get-WmiObject -ComputerName $ComputerName -Class Win32_LogonSession | %{
        $LogonType = $Null
        switch($_.LogonType) {
            $null {$LogonType = 'None'}
            0 { $LogonType = 'System' }
            2 { $LogonType = 'Interactive' }
            3 { $LogonType = 'Network' }
            4 { $LogonType = 'Batch' }
            5 { $LogonType = 'Service' }
            6 { $LogonType = 'Proxy' }
            7 { $LogonType = 'Unlock' }
            8 { $LogonType = 'NetworkCleartext' }
            9 { $LogonType = 'NewCredentials' }
            10 { $LogonType = 'RemoteInteractive' }
            11 { $LogonType = 'CachedInteractive' }
            12 { $LogonType = 'CachedRemoteInteractive' }
            13 { $LogonType = 'CachedUnlock' }
            default { $LogonType = $_.LogonType}
        }

        New-Object PSObject -Property @{
            UserName = $LogonMap[$_.LogonId].UserName
            Domain = $LogonMap[$_.LogonId].Domain
            LogonId = $_.LogonId
            LogonType = $LogonType
            AuthenticationPackage = $_.AuthenticationPackage
            Caption = $_.Caption
            Description = $_.Description
            InstallDate = $_.InstallDate
            Name = $_.Name
            StartTime = $_.ConvertToDateTime($_.StartTime)
            ComputerName = $_.PSComputerName
        }
    }
}
