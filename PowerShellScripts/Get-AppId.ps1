
function Get-AppId {
<#
.SYNOPSIS

Returns references to AppIDs found in the registry.

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


    # AppIds are referenced in 3 locations: CLSIDs(HKCR\CLSID\<CLSID>!AppId, the AppId key(HKCR\AppId\<AppIdGuid>, and the AppId name(HKCR\AppId\<AppIdExeName>!AppId).
    # Just becausue a reference to an AppId does not guarantee the AppId exists. We want to know about all refences to AppIds, so let's get them all

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


<#Additional interesting fields
LocalServicePath = $null       # If LocalService is defined, get the path to the service executable
LocalServiceIsDotNet = $null
DllSurrogateExecutablePath
DllSurrogateExecutableIsDotNet
DllSurrogatePath = $null
DllSurrogateIsDotNet = $null

Get the clsid associated with DCOM object and check the LocalServer32, LocalServer, or LocalService values/keys to see if they're dot net apps



#>

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

# TODO: Can we exploit managed DLLs in a DllSurrogate process?
# Note: I ignore LocalServer (not LocalServer32).  I've yet to see a 16-bit COM server
function Get-ExploitableDCOMApplications {
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
            $ServiceExePath = Get-PathFromCommandLine -CommandLine $ServiceCommandLine

            if(Test-DotNetAssembly $ServiceExePath) {
                New-Object PSObject -Property @{
                    AppId = $AppId.AppId
                    Clsid = $AppId.Clsid
                    LocalServer32 = $null
                    Service = $AppId.LocalService
                    ServicePath = $ServiceExePath
                }
            }
        }

        # If no service, check out-of-proc COM servers
        if($AppId.Clsid -and $AppId.LocalService -eq $null) {
            foreach($Clsid in $AppId.Clsid) {
                $LocalServer32 = (Get-ItemProperty "$BasePath\CLSID\$($AppId.Clsid)\LocalServer32" -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
                $LocalServer32PEPath = Get-PathFromCommandLine -CommandLine $LocalServer32


                if(Test-DotNetAssembly $LocalServer32PEPath) {
                    New-Object PSObject -Property @{
                        AppId = $AppId.AppId
                        Clsid = $AppId.Clsid
                        #LocalServer = $LocalServer
                        LocalServer32 = $LocalServer32PEPath
                        Service = $null
                        ServicePath = $null
                    }
                }
            }
        }
    }
}


function Get-PathFromCommandLine
{
    Param
    (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CommandLine
    )

    Begin {
    }

    Process {

        if(Test-Path -Path $CommandLine -ErrorAction SilentlyContinue)
        {
            $CommandLine
        }
        else
        {
             if($CommandLine.StartsWith('"')) {
                 if($CommandLine -match '^"(?<path>.+?)"') { 
                    $Matches['path']
                 } else {
                    Write-Error "Could not find path for command line that has quotes: $CommandLine"
                 }
             } else {
                $PathParts = $CommandLine -split ' '
                $Path = $null
                for($i=0; $i -lt $PathParts.Length; $i++) {
                    $TempPath = $PathParts[0..$i] -join ' '

                    if([System.IO.File]::Exists($TempPath)) {
                        $Path = $TempPath
                        break
                    } 
                }

                if($Path) {
                    $Path
                } else {
                    Write-Error "Could not find path for command line with no quotes: $CommandLine"
                }
             }
        }
    }
}
