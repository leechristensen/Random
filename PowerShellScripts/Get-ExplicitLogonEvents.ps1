function Get-ExplicitLogonEvents {
    [CmdletBinding()]
    Param(
        [int]
        $Days = 1
    )

    Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4648; StartTime=(Get-Date).AddDays(-$Days)} | ?{!$_.Properties[5].Value.EndsWith('$')} | %{

        $Properties = $_.Properties
        New-Object PSObject -Property @{
            TimeCreated       = $_.TimeCreated
            #SubjectUserSid    = $Properties[0].Value.ToString()
            SubjectUser        = "$($Properties[2].Value)\$($Properties[1].Value)"
            #SubjectLogonId    = $Properties[3].Value
            #LogonGuid         = $Properties[4].Value.ToString()
            TargetUser         = "$($Properties[6].Value)\$($Properties[5].Value)"
            #TargetLogonGuid   = $Properties[7].Value
            #TargetServerName  = $Properties[8].Value
            #TargetInfo        = $Properties[9].Value
            ProcessId         = $Properties[10].Value
            ProcessName       = $Properties[11].Value
            IpAddress         = $Properties[12].Value
            #IpPort            = $Properties[13].Value
        }
    } | select TimeCreated,TargetUser,ProcessName,ProcessId,SubjectUser,SubjectDomainName | ConvertTo-Csv -NoTypeInformation
}