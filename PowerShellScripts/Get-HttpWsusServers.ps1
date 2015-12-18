function Get-HttpWSUSServers {
    <#
    .SYNOPSIS
        Checks if the host recieves Windows updates over HTTP

        Author: Lee Christensen
        License: BSD 3-Clause
        Required Dependencies: None
        Optional Dependencies: None
        
    .DESCRIPTION
        This function checks to see if the host recieves Windows updates over HTTP.
        If so, one can escalate privileges by changing the host's proxy to point to an
        attacker's server.  The attacker can then trigger a Windows update, man in the
        middle the traffic, and serve a malicious exe that will execute as SYSTEM.
    
    .EXAMPLE
        > Get-HttpWSUSServers
        Gets HTTP Windows Update servers
    
    .LINK
        https://github.com/ctxis/wsuspect-proxy
        https://www.blackhat.com/docs/us-15/materials/us-15-Stone-WSUSpect-Compromising-Windows-Enterprise-Via-Windows-Update-wp.pdf

    #>

    [CmdletBinding()]
    Param()

    $UseWUServer = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name UseWUServer -ErrorAction SilentlyContinue).UseWUServer
    $WUServer = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name WUServer -ErrorAction SilentlyContinue).WUServer

    if($UseWUServer -eq 1 -and $WUServer.ToLower().StartsWith("http://")) {
        New-Object PSObject -Property @{
            WUServer = $WUServer
        }
    }
}
