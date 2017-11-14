
function Get-AppId {
<#
.SYNOPSIS

Returns references to AppIDs (aka DCOM servers) found in the registry.

Author: Lee Christensen (@tifkin_)  
License: BSD 3-Clause  
Required Dependencies: None  

.DESCRIPTION

Returns refeneces to AppIDs found in the HKEY_CLASSES_ROOT registry hive. Just
because an AppID is referenced in the registry does not mean that it is 
functional.  For example, several CLSIDs reference AppId GUIDs that do not 
exist. Likewise, named AppId executables(HKCR\AppId\ExecutableName\) sometimes
reference non-existent AppId GUIDs.

TODO: Handle settings in HKCR\Appid\<ExecutableName>. I've only seen one example of this: HKCR\AppId\slui.exe\IsFlighted
TODO: Is HKEY_CLASSES_ROOT\Classes\AppID\ a valid location for AppIds? I've only seen one application use it - Intel's graphics driver.

.PARAMETER Id

Specifies the AppId to return.

.EXAMPLE

Get-AppId -Id '{00020800-0000-0000-C000-000000000046}'

#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [Guid[]]
        $Id,

        [switch]
        $X86
    )

    if($X86) {
        $BasePath = "Registry::HKEY_CLASSES_ROOT\WOW6432Node"
    } else {
        $BasePath = "Registry::HKEY_CLASSES_ROOT"
    }
    
    # Documented AppId settings: https://msdn.microsoft.com/en-us/library/windows/desktop/ms682359(v=vs.85).aspx
    # Doing this because some AppIds use undocumented settings
    $DocumentedAppIdsettings = @('','accesspermission','activateatstorage','appid','appidflags','authenticationlevel','dllsurrogate','dllsurrogateexecutable','endpoints','launchpermission','loadusersettings','localservice','preferredserverbitness','remoteservername','rotflags','runas','serviceparameters','srptrustlevel')


    # AppIds are referenced in 3 locations: CLSIDs(HKCR\CLSID\<CLSID>!AppId, the AppId key(HKCR\AppId\<AppIdGuid>, and the AppId name(HKCR\AppId\<AppIdExeName>!AppId).  Maybe HKEY_CLASSES_ROOT\Classes\AppID\ as well.
    # Just because a reference to an AppId exists does not guarantee the AppId exists. I want to know about all refences to AppIds, so let's get them all whether they're valid or not.
    # The HasAppIdKey property indicates that it's a valid AppId

    # Get CLSIDs with registered AppIds.
    $AppidClsidMap = @{}
    Get-ItemProperty -Path "$BasePath\CLSID\*" -Name AppId -ErrorAction SilentlyContinue | Where-Object { $_.AppId.Trim() -ne '' } | ForEach-Object {
        if($AppidClsidMap[$_.AppId]) {
            $AppidClsidMap[$_.AppId] += $_.PSChildName
        } else {
            $AppidClsidMap[$_.AppId] = @($_.PSChildName)
        }
    }

    # Registered AppIds
    $RegisteredAppIds = (Get-Item "$BasePath\AppId\").GetSubKeyNames() | Where-Object {$_.StartsWith('{')}
    foreach($RegisteredAppId in $RegisteredAppIds) {
        if(!$AppidClsidMap[$RegisteredAppId]) {
            $AppidClsidMap[$RegisteredAppId] = $null
        }
    }


    # AppId executable names.
    $AppidExecutableNameMapping = @{}
    Get-ItemProperty -Path "$BasePath\AppId\*" -Name AppId -ErrorAction SilentlyContinue | Where-Object { $_.AppId.Trim() -ne '' } | ForEach-Object {
        if($AppidExecutableNameMapping[$_.AppId]) {
            $AppidExecutableNameMapping[$_.AppId] += $_.PSChildName
        } else {
            $AppidExecutableNameMapping[$_.AppId] = @($_.PSChildName)
        }
    }

    foreach($AppId in $AppidExecutableNameMapping.Keys) {
        if(!$AppidClsidMap[$AppId]) {
            $AppidClsidMap[$AppId] = $null
        }
    }

    if($Id) {
        $AppIdArray = New-Object System.Collections.ArrayList
        foreach($AppId in $Id) {
            $AppIdGuidStr = "{$AppId}"
            if($AppidClsidMap.Keys -contains $AppIdGuidStr) {
                $null = $AppIdArray.Add($AppIdGuidStr)
            } else {
                Write-Error "No references to the AppId $AppId exist."
            }
        }
    } else {
       $AppIdArray = $AppidClsidMap.Keys
    }
    
    foreach($AppId in $AppIdArray) {
        $AppIdKey = Get-Item "$BasePath\AppId\$($AppId)" -ErrorAction SilentlyContinue
        $HasAppIdKey = $AppIdKey -ne $null
        
        $Output = [ordered]@{
            Clsid = $AppidClsidMap[$AppId]
            NamedExecutable = $AppidExecutableNameMapping[$AppId]
            HasAppIdKey = $HasAppIdKey
            Name = $null
            UnknownSettings = $null
            UnknownSubKeys = $null
    
            # Documented Settings - https://msdn.microsoft.com/en-us/library/windows/desktop/ms682359(v=vs.85).aspx
            AccessPermission = $null
            ActivateAtStorage = $null
            AppId = $AppId
            AppIdFlags = $null
            AuthenticationLevel = $null
            DllSurrogate = $null
            DllSurrogateExecutable = $null
            Endpoints = $null
            LaunchPermission = $null
            LoadUserSettings = $null
            LocalService = $null
            PreferredServerBitness = $null
            RemoteServerName = $null
            ROTFlags = $null
            RunAs = $null
            ServiceParameters = $null
            SRPTrustLevel = $null
        }
        
    
        if($HasAppIdKey) {
            
            # Grab the settings
            foreach($ValueName in $AppIdKey.GetValueNames()) {
                if($DocumentedAppIdsettings -contains ($ValueName.ToLower())) {
                    if($ValueName -eq '') {
                        $Output['Name'] = $AppIdKey.GetValue('')
                    } else {
                        $Output[$ValueName] = $AppIdKey.GetValue($ValueName)
                    }
                }
                else {
                    if($Output['UnknownSettings'] -eq $null) {
                        $Output['UnknownSettings'] = @{}
                    }
                    $Output['UnknownSettings'][$ValueName] = $AppIdKey.GetValue($ValueName)
                }
            }
    
            # Deal with any subkeys
            if($AppIdKey.SubKeyCount -gt 0) {
                foreach($SubKeyName in $AppIdKey.GetSubKeyNames()) {
                    # Sometime apps register these settings in the subkeys instead of the registry value
                    if($SubKeyName -eq 'LaunchPermission' -or $SubKeyName -eq 'AccessPermission') {
                        $SubKey = $AppIdKey.OpenSubKey($SubKeyName)
    
                        if($Output[$SubKeyName]) {
                            Write-Warning "The AppId $AppId defines two $SubKeyName values. Not going to return the value defined in the $SubKeyName SubKey."
                        } else {
                            $Output[$SubKeyName] = $SubKey.GetValue('')
                        }
    
                    } else {
                        if(!$Output['UnknownSubKeys']) {
                            $Output['UnknownSubKeys'] = @()
                        }
    
                        $Output['UnknownSubKeys'] += $SubKeyName
                    }
                }
            }
        }
    
        New-Object -TypeName PSObject -Property $Output
    } 
}


function Get-DcomObject {
    [CmdletBinding(DefaultParameterSetName = 'AppId')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName='AppId')]
        [ValidateNotNullOrEmpty()]
        [Guid]
        $AppId,

        [Parameter(Mandatory = $true, ParameterSetName='ProgId')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ProgId,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ComputerName = 'localhost'
    )

    try {
        if($AppId) {
            $Type = [Type]::GetTypeFromCLSID("{$($AppId)}", $ComputerName)
        } else {
            $Type = [Type]::GetTypeFromProgID($ProgId, $ComputerName)
        }
        
        [Activator]::CreateInstance($Type)
    } catch {
        Write-Error $_
    }
}


function Test-DotNetAssembly {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    Begin {
    }

    Process {
        try {
            $null = [System.Reflection.AssemblyName]::GetAssemblyName($Path)
            $true
        } catch {
            $false
        }
    }
}


function Get-ExploitableDCOMServers {
<#
.SYNOPSIS

Returns references to AppIDs (aka DCOM servers) whose backing PE file is a .NET assembly.

Author: Lee Christensen (@tifkin_)  
License: BSD 3-Clause  
Required Dependencies: None  

.DESCRIPTION

Returns references to AppIDs (aka DCOM servers) whose backing PE file is a .NET
assemlby. An attacker leverage them to elevate privileges or as an alternative 
remote code execution technique. See James Forshaw's work at the follow URLs
for more information:

https://github.com/tyranid/ExploitDotNetDCOM
https://bugs.chromium.org/p/project-zero/issues/detail?id=1075

TODO: Can we exploit managed DLLs in a DllSurrogate processes?

.PARAMETER X86

Search for X86 AppId/Clsid.

.EXAMPLE

Get-AppId -Id '{00020800-0000-0000-C000-000000000046}'

#>
    [CmdletBinding()]
    Param(
    [switch]
        $X86
    )

    if($X86) {
        $BasePath = "Registry::HKEY_CLASSES_ROOT\WOW6432Node"
    } else {
        $BasePath = "Registry::HKEY_CLASSES_ROOT"
    }

    $AppIds = Get-AppId @PSBoundParameters

    foreach($AppId in $AppIds) {
        
        if($AppId.LocalService) {
            # TODO: Account for service DLLs
            $ServiceCommandLine = (Get-WmiObject Win32_Service -Filter "name='$($AppId.LocalService)'" -Property PathName -ErrorAction SilentlyContinue).PathName
            if($ServiceCommandLine -and $ServiceCommandLine -ne [String]::Empty) {
                $ServiceExePath = Resolve-CommandLineToFilePath -CommandLine $ServiceCommandLine

                if($ServiceExePath.Path) {
                    if(Test-DotNetAssembly $ServiceExePath.Path) {
                        New-Object PSObject -Property @{
                            AppId = $AppId.AppId
                            Clsid = $AppId.Clsid
                            LocalServer32 = $null
                            Service = $AppId.LocalService
                            ServicePath = $ServiceExePath.Path
                        }
                    }
                }
            } else {
                Write-Error "AppId $($AppId.AppId) uses the service $($AppId.LocalService). However, the path to the service's executable could not be found"
            }
        }

        # If no service, check out-of-proc COM servers
        if($AppId.Clsid -and $AppId.LocalService -eq $null) {
            foreach($Clsid in $AppId.Clsid) {
                $LocalServer32 = (Get-ItemProperty "$BasePath\CLSID\$($AppId.Clsid)\LocalServer32" -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
                
                if($LocalServer32 -and $LocalServer32 -ne [String]::Empty) {
                    $LocalServer32PEPath = Resolve-CommandLineToFilePath -CommandLine $LocalServer32

                    if($LocalServer32PEPath.Path) {
                        if(Test-DotNetAssembly -Path $LocalServer32PEPath.Path) {
                            New-Object PSObject -Property @{
                                AppId = $AppId.AppId
                                Clsid = $AppId.Clsid
                                LocalServer32 = $LocalServer32PEPath.Path
                                Service = $null
                                ServicePath = $null
                            }
                        }
                    } else {
                        Write-Error "Clsid $Clsid registers a LocalServer32 key that refers to a non-existant COM server. LocalServer32: $LocalServer32"
                    }
                }
            }
        }
    }
}


function Resolve-CommandLineToFilePath
{
    <#
    .SYNOPSIS

    The Resolve-CommandLineToFilePath function takes an arbitrary Command Line and resolves the called application/file's path.

    .PARAMETER CommandLine

    The CommandLine that you want to convert to a file path.

    .NOTES
    
    Author: Jared Atkinson (@jaredcatkinson)
    License: BSD 3-Clause
    Required Dependencies: PSReflect
    Optional Dependencies: None
    TODO: WorkingDirectory and EnvironmentVariable parameters
    TODO: Throw error if no FilePath is found

    .EXAMPLE
    Resolve-CommandLineToFilePath -CommandLine '%windir%\system32\rundll32.exe'
    
    CommandLine                    Path
    -----------                    ----
    %windir%\system32\rundll32.exe C:\WINDOWS\system32\rundll32.exe

    .EXAMPLE
    'cmd' | Resolve-CommandLineToFilePath

    CommandLine Path
    ----------- ----
    cmd         C:\WINDOWS\system32\cmd.EXE

    .EXAMPLE
    (Get-WmiObject -Class win32_service).PathName | Resolve-CommandLineToFilePath

    CommandLine                                                                               Path
    -----------                                                                               ----
    C:\Windows\SysWOW64\Macromed\Flash\FlashPlayerUpdateService.exe                           C:\Windows\SysWOW64\Macromed\Flash\...
    C:\WINDOWS\system32\svchost.exe -k LocalServiceNetworkRestricted                          C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\System32\alg.exe                                                               C:\WINDOWS\System32\alg.exe
    C:\WINDOWS\system32\svchost.exe -k LocalServiceNetworkRestricted                          C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k netsvcs                                                C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k netsvcs                                                C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\System32\svchost.exe -k AppReadiness                                           C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\system32\AppVClient.exe                                                        C:\WINDOWS\system32\AppVClient.exe
    C:\WINDOWS\system32\svchost.exe -k wsappx                                                 C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\aspnet_state.exe                          C:\WINDOWS\Microsoft.NET\Framework6...
    C:\WINDOWS\System32\svchost.exe -k LocalSystemNetworkRestricted                           C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\System32\svchost.exe -k LocalServiceNetworkRestricted                          C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k AxInstSVGroup                                          C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\System32\svchost.exe -k netsvcs                                                C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k LocalServiceNoNetwork                                  C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\System32\svchost.exe -k netsvcs                                                C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k DcomLaunch                                             C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\System32\svchost.exe -k netsvcs                                                C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\System32\svchost.exe -k LocalServiceAndNoImpersonation                         C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k LocalService                                           C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k LocalService                                           C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k netsvcs                                                C:\WINDOWS\system32\svchost.exe
    "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\OfficeClickToRun.exe" /service C:\Program Files\Common Files\Micro...
    C:\WINDOWS\System32\svchost.exe -k wsappx                                                 C:\WINDOWS\System32\svchost.exe
    C:\WINDOWS\system32\dllhost.exe /Processid:{02D4B3F1-FD88-11D1-960D-00805FC79235}         C:\WINDOWS\system32\dllhost.exe
    C:\WINDOWS\system32\svchost.exe -k LocalServiceNoNetwork                                  C:\WINDOWS\system32\svchost.exe
    C:\WINDOWS\system32\svchost.exe -k NetworkService                                         C:\WINDOWS\system32\svchost.exe
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $CommandLine
    )

    process
    {
        foreach($command in $CommandLine)
        {
            $props = @{
                 CommandLine = $command
                 Path = $null
            }

            # Expand Environment Variable
            $command = [System.Environment]::ExpandEnvironmentVariables($command)
            
            # Remove Quotes from the Path
            $command = $command.Replace('"','')

            if(Test-Path -Path $command -PathType Leaf)
            {
                $props['Path'] = $command
            }
            else
            {
                $sb = New-Object -TypeName System.Text.StringBuilder
        
                # We are going to split the command line on spaces and test each iteration
                :outer foreach($pathsegment in ($command -split ' ' | Where-Object { $_ }))
                {
                    $sb.Append($pathsegment) | Out-Null
                    $finalpath = $sb.ToString()

                    Write-Verbose "Testing: $($finalpath)"
                    if(Test-Path -Path $finalpath -PathType Leaf)
                    {
                        $props['Path'] = $finalpath
                        break outer
                    }

                    :inner foreach($pathext in ($env:PATHEXT -split ';' | Where-Object { $_ } )) 
                    {
                        Write-Verbose "Testing: $($finalpath)$($pathext)"
                        if(Test-Path -Path "$($finalpath)$($pathext)" -PathType Leaf)
                        {
                            $props['Path'] = "$($finalpath)$($pathext)"
                            break outer
                        }

                        :innermost foreach($path in ($env:PATH -split ';' | Where-Object { $_ } ))
                        {
                            Write-Verbose "Testing: $($path)\$($finalpath)"
                            if(Test-Path -Path "$($path)\$($finalpath)" -PathType Leaf)
                            {
                                $props['Path'] = "$($path)\$($finalpath)"
                                break outer
                            }

                            Write-Verbose "Testing: $($path)\$($finalpath)$($pathext)"
                            if(Test-Path -Path "$($path)\$($finalpath)$($pathext)" -PathType Leaf)
                            {
                                $props['Path'] = "$($path)\$($finalpath)$($pathext)"
                                break outer
                            }
                        }
                    }
                    $sb.Append(' ') | Out-Null
                }
            }

            New-Object -TypeName psobject -Property $props
        }
    }
}
