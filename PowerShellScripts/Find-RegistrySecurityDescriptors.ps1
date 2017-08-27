function Find-RegistrySecurityDescriptors {
<#
.SYNOPSIS

Recursively searches the registry for potential security descriptors.

This script is a modified version of Search-Registry.ps1 by Bill Stewart
 - http://windowsitpro.com/scripting/searching-registry-powershell

Author: Lee Christensen (@tifkin_)  
License: BSD 3-Clause  
Required Dependencies: PSv3  

.DESCRIPTION

Searches the registry for potential security descriptors. For binary registry 
values, the script attempts to create a security descriptor from the bytes 
using the System.Security.AccessControl.CommonSecurityDescriptor class's 
constructor.  For string values, the script attempts to parse the value as an
SDDL or it uses a regex to try search for values commonly seen in SDDLs (values
identified by the regex are marked as "Uncertain" in the "Note" output property).

.PARAMETER StartKey

Location the script should begin searching from.

.PARAMETER ComputerName

Specifies the system to search.

.EXAMPLE

Find-RegistrySecurityDescriptors -StartKey 'HKLM:\'

#>
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [String] 
        $StartKey = 'HKLM:\',
        
        [Parameter(ValueFromPipeline=$true)]
        [String[]]
        $ComputerName=$ENV:COMPUTERNAME
    )

    begin {
        $PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("ComputerName")) -and (-not $ComputerName)
        
        # Throw an error if -Pattern is not valid
        try {
          "" -match $Pattern | out-null
        }
        catch [System.Management.Automation.RuntimeException] {
          throw "-Pattern parameter not valid - $($_.Exception.Message)"
        }
        
        # These two hash tables speed up lookup of key names and hive types
        $HiveNameToHive = @{
          "HKCR"               = [Microsoft.Win32.RegistryHive] "ClassesRoot";
          "HKEY_CLASSES_ROOT"  = [Microsoft.Win32.RegistryHive] "ClassesRoot";
          "HKCU"               = [Microsoft.Win32.RegistryHive] "CurrentUser";
          "HKEY_CURRENT_USER"  = [Microsoft.Win32.RegistryHive] "CurrentUser";
          "HKLM"               = [Microsoft.Win32.RegistryHive] "LocalMachine";
          "HKEY_LOCAL_MACHINE" = [Microsoft.Win32.RegistryHive] "LocalMachine";
          "HKU"                = [Microsoft.Win32.RegistryHive] "Users";
          "HKEY_USERS"         = [Microsoft.Win32.RegistryHive] "Users";
        }
        $HiveToHiveName = @{
          [Microsoft.Win32.RegistryHive] "ClassesRoot"  = "HKCR:";
          [Microsoft.Win32.RegistryHive] "CurrentUser"  = "HKCU:";
          [Microsoft.Win32.RegistryHive] "LocalMachine" = "HKLM:";
          [Microsoft.Win32.RegistryHive] "Users"        = "HKU:";
        }
        
        # Search for 'hive:\startkey'; ':' and starting key optional
        $StartKey | select-string "([^:\\]+):?\\?(.+)?" | foreach-object {
          $HiveName = $_.Matches[0].Groups[1].Value
          $StartPath = $_.Matches[0].Groups[2].Value
        }
        
        if (-not $HiveNameToHive.ContainsKey($HiveName)) {
          throw "Invalid registry path"
        } else {
          $Hive = $HiveNameToHive[$HiveName]
          $HiveName = $HiveToHiveName[$Hive]
        }
        
        # Recursive function that searches the registry
        function search-registrykey($computerName, $rootKey, $keyPath) {
          # Write error and return if unable to open the key path as read-only
          try {
            $subKey = $rootKey.OpenSubKey($keyPath, $FALSE)
          }
          catch [System.Management.Automation.MethodInvocationException] {
            $message = $_.Exception.Message
            write-error "$message - $HiveName\$keyPath"
            return
          }
        
          # Write error and return if the key doesn't exist
          if (-not $subKey) {
            write-error "Key does not exist: $HiveName\$keyPath" -category ObjectNotFound
            return
          }
        
          # Search for value and/or data; -MatchValue also returns the data
          foreach ($valueName in $subKey.GetValueNames()) {
                
              $ValueData = $subKey.GetValue($valueName)
              $ValueType = $subKey.GetValueKind($ValueName)
        
              if($ValueType -eq 'Binary') {
                  
                  try {
                      $null = New-Object -TypeName System.Security.AccessControl.CommonSecurityDescriptor -ArgumentList $true,$false, $ValueData,0
                          
                      New-Object PSObject -Property ([ordered]@{
                          ComputerName = $computerName
                          Path = "$HiveName\$keyPath"
                          ValueName = $valueName
                          Value = [Convert]::ToBase64String($ValueData)
                          ValueType = $ValueType
                          Note = ''
                      })
                  } catch {
                      #Write-Error $_
                  }
        
              } elseif($ValueType -eq 'String') {
                  if($ValueData.Trim() -eq '') {
                      Write-Verbose 'null, so skipping'
                      continue
                  }
        
                  try {
                      if($ValueData | ConvertFrom-SddlString -ErrorAction SilentlyContinue) {
                          New-Object PSObject -Property ([ordered]@{
                              ComputerName = $computerName
                              Path = "$HiveName\$keyPath"
                              ValueName = $valueName
                              Value = $ValueData
                              ValueType = $ValueType
                              Note = ''
                          })
                      }
                  } catch {
                      # Rough heuristic to get SDDLs
                      if($ValueData -match '((A;)|(D:)|(O:))..+' -and $ValueData -notmatch 'clsid|progid') {
                          New-Object PSObject -Property ([ordered]@{
                              ComputerName = $computerName
                              Path = "$HiveName\$keyPath"
                              ValueName = $valueName
                              Value = $ValueData
                              ValueType = $ValueType
                              Note = 'Uncertain'
                          })
                      }
                  }
              }
          }
        
          # Iterate and recurse through subkeys; if -MatchKey requested, output
          # objects only report computer and key (keys do not have values or data)
          foreach ($keyName in $subKey.GetSubKeyNames()) {
              if ($keyPath -eq "") {
                  $subkeyPath = $keyName
              } else {
                  $subkeyPath = $keyPath + "\" + $keyName
              }
              
              # $matchCount is a reference
              search-registrykey $computerName $rootKey $subkeyPath
          }
        
          # Close opened subkey
          $subKey.Close()
        }
        
        # Core function opens the registry on a computer and initiates searching
        function search-registry2($computerName) {
        # Write error and return if unable to open the key on the computer
        try {
            $rootKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Hive,
              $computerName)
          }
          catch [System.Management.Automation.MethodInvocationException] {
            $message = $_.Exception.Message
            Write-Error "$message - $computerName"
            return
          }
        
          search-registrykey $computerName $rootKey $StartPath
          $rootKey.Close()
        }
    }

    Process {
       if ($PIPELINEINPUT) {
           search-registry2 $_
       }
       else {
           $ComputerName | foreach-object {
             search-registry2 $_
           }
         }
    }
}
