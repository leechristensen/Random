# Based on the code found in https://posts.specterops.io/data-source-analysis-and-dynamic-windows-re-using-wpp-and-tracelogging-e465f8b653f7
function Start-EtwTrace {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [Guid]
        $ProviderGuid,

        [Parameter(Position=1, Mandatory=$true)]
        [string]
        $OutputFile,

        [Parameter(Position=2, Mandatory=$true)]
        [string]
        $ProcessPath,

        [Parameter(Position=3, Mandatory=$false)]
        [string]
        $ArgumentList,


        [Parameter(Mandatory=$false)]
        [byte]
        $Level = 0xFF,

        [Parameter(Mandatory=$false)]
        [UInt32]
        $Property = 0x40,


        [Parameter(Mandatory=$false)]
        [switch]
        $Force
    )

    if((Test-Path $OutputFile -ErrorAction SilentlyContinue)) {
        Remove-Item -Force:$Force $OutputFile -ErrorAction Stop
    }

    if(!(Test-Path $ProcessPath -ErrorAction SilentlyContinue)) {
        throw "Could not find the executable $($ProcessPath)"
    }

    $EtwProviderGuid = $ProviderGuid
    $SessionName = 'tempLoggingProvider'

    Write-Warning "Creating the trace session '$($SessionName)'..."
    $Session = New-EtwTraceSession -Name $SessionName -LogFileMode 0x08000100 -FlushTimer 1 -ErrorAction Stop
    $TraceProvider = Add-EtwTraceProvider -SessionName $Session.Name -Guid $EtwProviderGuid -MatchAnyKeyword 0xFFFFFFFFFFFF -Level $Level -Property $Property
    
    Write-Warning "Starting tracerpt..."
    $TraceProcess = Start-Process -PassThru tracerpt.exe -ArgumentList "-rt $($SessionName) -y -o $($OutputFile) -of EVTX" -WindowStyle Hidden

    sleep 1

    $ProcArgs = @{ FilePath = $ProcessPath }
    if($ArgumentList) {
        $ProcArgs['ArgumentList'] = $ArgumentList
    }
    
    $TargetProc = Start-Process @ProcArgs -PassThru -Wait
    Write-Warning "Analyzed Process ID: $($TargetProc.Id)"
    

    sleep -Milliseconds 1200  # Wait a bit for the last events to come in

    Write-Warning "Removing the trace session '$($SessionName)'..."
    $null = $TraceProcess.CloseMainWindow()

    $null = Remove-EtwTraceSession -Name $SessionName
    Sleep 1
    
    Get-WinEvent -Path $OutputFile | sort TimeCreated 
}
