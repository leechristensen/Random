<#
Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

.Synopsis
   Returns all the Windows events in a given time period
.DESCRIPTION
   Returns all the Windows events in a given time period.  Useful for determining events that actions create on a system.
.EXAMPLE
   Get-AllWinEvents (Get-Date).AddMinutes(-2)
#>

function Get-AllWinEvents
{
    [CmdletBinding()]
    Param
    (
        # Time when logs started being created
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [DateTime]
        $StartTime,

        # Time when logs stopped being generated
        [DateTime]
        $EndTime=(Get-Date)
    )

    $StartTime = (Get-Date).AddMinutes(-2)

    $Logs = Get-WinEvent -ListLog * | Where-Object { $_.recordcount} 
    $NewLogs = @()
    foreach($log in $Logs)
    {
        Get-WinEvent -FilterHashTable @{LogName=$log.LogName;StartTime=$StartTime;EndTime=$EndTime} -ErrorAction SilentlyContinue | %{
            $NewLogs += $_
        }
    }

    $NewLogs
}

Read-Host "Hit enter when you are ready to perform an action"
$StartTime = Get-Date

# Do something

Read-Host "Hit any key once the action has completed"
$EndTime = Get-Date

$StartTime
$EndTime
Write-Verbose "Waiting for events to be writting..."
$logs = Get-AllWinEvents -StartTime $StartTime -EndTime $EndTime
$logs | select id,TimeCreated,message,ProvderName,LevelDisplayName,OpcodeDisplayName,TaskDisplayName,ProcessId | Out-GridView
