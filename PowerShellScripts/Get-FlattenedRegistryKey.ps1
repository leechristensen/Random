<#
Author: Lee Christensen (@tifkin_)  
License: BSD 3-Clause    
#>

function Get-FlattenedRegistryKey {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        $Path
    )
    
    function GetFlattenedRegistryKey {
        [CmdletBinding()]
        Param(
            [Parameter(Position=0, Mandatory=$true)]
            $Path,

            [Parameter(Position=1, Mandatory=$false)]
            [int]
            $Depth,

            [Parameter(Position=2, Mandatory=$false)]
            [Regex]
            $SearchTerm
        )

        $KeyName = $Path.Substring($Path.LastIndexOf('\')+1)

        #1) Get the properties of the current key
        try {
            $Key = Get-Item -LiteralPath $Path -ErrorAction Stop
        } catch {
            Write-Error "$($_.Exception.Message) Location: $Key"
            $Key = $null
        }

        if($Key) {
            $ValueNames = $Key.GetValueNames()


            # Sometimes GetValueNames doesn't include the default value, so let's explicitly grab it

            New-Object PSObject -Property ([ordered]@{
                Key = "$($Key.PSPath)\".Replace($script:g_ParentKeyName, '')
                ValueName = '(default)'
                Value = $Key.GetValue('',$null)
            })


            foreach($ValueName in $ValueNames) {
                
                if($ValueName -eq '') {
                    # Already dealt with default value above
                    continue
                }

                try {
                    $Value = $Key.GetValue($ValueName,$null)

                    New-Object PSObject -Property ([Ordered]@{
                        Key = "$($Key.PSPath)\".Replace($script:g_ParentKeyName, '')
                        ValueName = $ValueName
                        Value = $Value
                    })
                } catch {
                    
                    Write-Error $_
                }
            }

            # 2) Get the values in the subkeys
            foreach($SubkeyName in $Key.GetSubKeyNames()) {
                GetFlattenedRegistryKey -Path "$($Key.PSPath)\$($SubKeyName)" -Depth $Depth -SearchTerm $SearchTerm
            }
        }
    }
    

    $RootKeys = Get-Item -Path $Path -ErrorAction SilentlyContinue

    if($RootKeys) {
        foreach($Root in $RootKeys) {
            $script:g_ParentKeyName = "$($Root.PSParentPath)\"
            GetFlattenedRegistryKey -Path $Root.PSPath 
        }
    } else {
        Write-Error "Could not find root key $Path"
    }

    Remove-Variable -Scope Script -Name g_ParentKeyName -ErrorAction SilentlyContinue
}

