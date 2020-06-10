
function Get-LogoffEvents {
    [CmdletBinding()]
    Param(
        [int]
        $Days = 1
    )

    Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4634; StartTime=(Get-Date).AddDays(-$Days)} | %{
        $Properties = $_.Properties
        New-Object PSObject -Property @{
            TimeCreatedUtc   = $_.TimeCreated.ToUniversalTime().ToString()
            TimeCreatedLocal = $_.TimeCreated.ToLocalTime().ToString()
            #TargetUserSid   = $Properties[0].Value.ToString()
            TargetUserName   = $Properties[1].Value
            TargetDomainName = $Properties[2].Value
            TargetLogonId    = $Properties[3].Value
            LogonType        = $Properties[4].Value.ToString()
        }
    } | select TimeCreatedLocal,TimeCreatedUtc,TargetUserName,TargetDomainName,TargetLogonId,LogonType | ConvertTo-Csv -NoTypeInformation
}