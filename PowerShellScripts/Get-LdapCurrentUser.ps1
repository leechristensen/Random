function Get-LdapCurrentUser {
<#
.SYNOPSIS

Gets the current user who is authenticating to LDAP

Author: Lee Christensen (@tifkin_)  
License: BSD 3-Clause  
Required Dependencies: None

.DESCRIPTION

Gets the current user who is authenticating to LDAP. It does so by using the 
LDAP_SERVER_WHO_AM_I_OID extended operation (MS-ADTS 3.1.1.3.4.2.4 
LDAP_SERVER_WHO_AM_I_OID - https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/faf0b8c6-8c59-439f-ac62-dc4c078ed715).

.PARAMETER Server

LDAP server to connect to (likely a Domain Controller)

.PARAMETER AuthType

Protocol to use during authentication

.PARAMETER Certificate

Certificate (.pfx file) to use during authentication

.PARAMETER Certificate

Certificate file's password

.PARAMETER UseSSL

Whether to use SSL/TLS (LDAPS) when connecting

.PARAMETER Signing

Connect with Signing enabled

.PARAMETER Sealing

Connect with Sealing enabled

.PARAMETER VerifyServerCertificate

Verify that the server certificate is trusted

#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]
        $Server,

        [Parameter(Position=1, Mandatory=$false)]
        [ValidateSet('Anonymous','Basic','Negotiate','Ntlm','Digest','Sicily','Dpa','Msn','External','Kerberos')]
        $AuthType,

        [Parameter(Position=3, Mandatory=$false)]
        [string]
        $Certificate,

        [Parameter(Position=4, Mandatory=$false)]
        [string]
        $CertificatePassword,

        [Parameter(Mandatory=$false)]
        [switch]
        $UseSSL = $false,

        [Parameter(Mandatory=$false)]
        [switch]
        $Signing = $false,

        [Parameter(Mandatory=$false)]
        [switch]
        $Sealing = $false,

        [Parameter(Mandatory=$false)]
        [switch]
        $VerifyServerCertificate
    )

    try {
        $null = [System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.Protocols")
        $null = [System.Reflection.Assembly]::LoadWithPartialName("System.Net")

        
        if($Server) {
            $c = New-Object System.DirectoryServices.Protocols.LdapConnection $Server
        } else {
            $Ident = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier -ArgumentList @($null)
            $c = New-Object System.DirectoryServices.Protocols.LdapConnection $Ident
        }

        $c.SessionOptions.SecureSocketLayer = $UseSSL;

        if($Sealing) {
            $c.SessionOptions.Sealing = $true
        }

        if($Signing) {
            $c.SessionOptions.Signing = $true
        }
        
        if($AuthType) {
            $c.AuthType = $AuthType
        }

        if(!$VerifyServerCertificate) {
            $c.SessionOptions.VerifyServerCertificate = {$true}
        }

        if($Certificate) {
            $Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 @($Certificate, $CertificatePassword, 'Exportable')
            $null = $c.ClientCertificates.Add($Cert)
        }

        # 1.3.6.1.4.1.4203.1.11.3 = OID for LDAP_SERVER_WHO_AM_I_OID (see MS-ADTS 3.1.1.3.4.2 LDAP Extended Operations)
        $ExtRequest = New-Object System.DirectoryServices.Protocols.ExtendedRequest "1.3.6.1.4.1.4203.1.11.3"
        $resp = $c.SendRequest($ExtRequest)
        
        $str = [System.Text.Encoding]::ASCII.GetString($resp.ResponseValue)

        if([string]::IsNullOrEmpty($str)) {
            Write-Error "Authentication failed"
        } else {
            $str
        }
    } catch {
        Write-Error $_
    }
}
