function Get-AppId {
<#
.SYNOPSIS

Returns refeneces to AppIDs found in the registry.

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
        $Id
    )
    
    # Documented AppId settings: https://msdn.microsoft.com/en-us/library/windows/desktop/ms682359(v=vs.85).aspx
    # Doing this because some AppIds use undocumented settings
    $DocumentedAppIdsettings = @('','accesspermission','activateatstorage','appid','appidflags','authenticationlevel','dllsurrogate','dllsurrogateexecutable','endpoints','launchpermission','loadusersettings','localservice','preferredserverbitness','remoteservername','rotflags','runas','serviceparameters','srptrustlevel')


    # AppIds are referenced in 3 locations: CLSIDs(HKCR\CLSID\<CLSID>!AppId, the AppId key(HKCR\AppId\<AppIdGuid>, and the AppId name(HKCR\AppId\<AppIdExeName>!AppId).
    # Just becausue a reference to an AppId does not guarantee the AppId exists. We want to know about all refences to AppIds, so let's get them all

    # Get CLSIDs with registered AppIds.
    $AppidClsidMap = @{}
    Get-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\CLSID\* -Name AppId -ErrorAction SilentlyContinue | Where-Object { $_.AppId.Trim() -ne '' } | ForEach-Object {
        if($AppidClsidMap[$_.AppId]) {
            $AppidClsidMap[$_.AppId] += $_.PSChildName
        } else {
            $AppidClsidMap[$_.AppId] = @($_.PSChildName)
        }
    }

    # Registered AppIds
    $RegisteredAppIds = (Get-Item 'Registry::HKEY_CLASSES_ROOT\AppId\').GetSubKeyNames() | Where-Object {$_.StartsWith('{')}
    foreach($RegisteredAppId in $RegisteredAppIds) {
        if(!$AppidClsidMap[$RegisteredAppId]) {
            $AppidClsidMap[$RegisteredAppId] = $null
        }
    }


    # AppId executable names.
    $AppidExecutableNameMapping = @{}
    Get-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\AppId\* -Name AppId -ErrorAction SilentlyContinue | Where-Object { $_.AppId.Trim() -ne '' } | ForEach-Object {
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
        $AppIdKey = Get-Item "Registry::HKEY_CLASSES_ROOT\AppId\$($AppId)" -ErrorAction SilentlyContinue
        $AppIdIsRegistered = $AppIdKey -ne $null
        
        $Output = @{
            Clsid = $AppidClsidMap[$AppId]
            NamedExecutable = $AppidExecutableNameMapping[$AppId]
            IsRegistered = $AppIdIsRegistered
            Name = $null
            UnknownSettings = $null
            UnknownSubKeys = $null
    
            # Documented Settings
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
        
    
        if($AppIdIsRegistered) {
            
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
