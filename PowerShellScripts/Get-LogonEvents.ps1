function Get-LogonEvents {
    [CmdletBinding()]
    Param(
        [int]
        $Days = 1,

        [int]
        $MaxEvents,

        [string]
        $ComputerName
    )

    $Args = @{
        FilterHashtable = @{LogName='Security'; Id=4624; StartTime=((Get-Date).AddDays(-$Days))} 
    }

    if($MaxEvents) {
        $Args['MaxEvents'] = $MaxEvents
    }

    if($ComputerName) {
        $Args['ComputerName'] = $ComputerName
    }

    Get-WinEvent @Args -ErrorAction Stop | ?{$_.Properties[5].Value -notmatch "^(SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-\d+|UMFD-\d+)$" } | %{
        $Properties = $_.Properties

        $Obj = @{
            TimeCreated               = $_.TimeCreated
            #SubjectUserSid            = $Properties[0].Value.ToString()
            #SubjectUserName           = $Properties[1].Value
            #SubjectDomainName         = $Properties[2].Value
            #SubjectLogonId            = $Properties[3].Value
            Subject = "$($Properties[2].Value)\$($Properties[1].Value)"
            #TargetUserSid             = $Properties[4].Value.ToString()
            #TargetUserName            = $Properties[5].Value
            #TargetDomainName          = $Properties[6].Value
            #TargetLogonId             = $Properties[7].Value
            TargetUser = "$($Properties[6].Value)\$($Properties[5].Value)"
            LogonType                 = $Properties[8].Value
            #LogonProcessName          = $Properties[9].Value
            AuthenticationPackageName = $Properties[10].Value
            #WorkstationName           = $Properties[11].Value
            #LogonGuid                 = $Properties[12].Value
            #TransmittedServices       = $Properties[13].Value
            LmPackageName             = $Properties[14].Value
            #KeyLength                 = $Properties[15].Value
            #ProcessId                 = $Properties[16].Value
            #ProcessName               = $Properties[17].Value
            IpAddress                 = $Properties[18].Value
            #ImpersonationLevel        = $Properties[20].Value
            #RestrictedAdminMode       = $Properties[21].Value
            #TargetOutboundUserName    = $Properties[22].Value
            #TargetOutboundDomainName  = $Properties[23].Value
            TargetOutboundUser = "$($Properties[23].Value)\$($Properties[22].Value)"
            #VirtualAccount            = $Properties[24].Value
            #TargetLinkedLogonId       = $Properties[25].Value
            #ElevatedToken             = $Properties[26].Value
        }

        New-Object psobject -Property $Obj

    } | ConvertTo-Csv -NoTypeInformation

    Write-Warning 'Get-LogonEvents done'
}