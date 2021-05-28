function ConvertFrom-DsSchemaGuid {
<#
.SYNOPSIS

Converts an object schema GUID to a name

Author: Lee Christensen (@tifkin_)  
License: BSD 3-Clause  
Required Dependencies: None

Code heavily taken from https://www.pinvoke.net/default.aspx/ntdsapi/DsMapSchemaGuids.html


.DESCRIPTION

Converts an object schema GUID to a name.

.PARAMETER InputObject

Guid(s) to map to a name.

.EXAMPLE

ConvertFrom-DsSchemaGuid '3e10944d-c354-11d0-aff8-0000f80367c1'

.EXAMPLE

$Guids = (
    '{771727b1-31b8-4cdf-ae62-4fe39fadf89e}',
    'f6d6dd88-ccee-11d2-9993-0000f87a57d4',
    '3e10944d-c354-11d0-aff8-0000f80367c1'
)
ConvertFrom-DsSchemaGuid $Guids 'corp.local'

.EXAMPLE

'{771727b1-31b8-4cdf-ae62-4fe39fadf89e}', 'f6d6dd88-ccee-11d2-9993-0000f87a57d4' | ConvertFrom-DsSchemaGuid

#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Guid[]]
        $InputObject,

        [Parameter(Mandatory=$false, Position=1)]
        [string]
        $Domain
    )
    
    Begin {
        # Load the PInvoked code if it hasn't been loaded yet
        try {
            $null = New-Object 'Interop+DS_SCHEMA_GUID_MAP'
        } catch {
        
            # Taken from https://www.pinvoke.net/default.aspx/ntdsapi/DsMapSchemaGuids.html
        Add-Type  -Verbose -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public static class Interop {
    [DllImport("Ntdsapi.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint DsMapSchemaGuids(
        IntPtr hDs,
        uint cGuids,
        Guid[] rGuids,
        out IntPtr ppGuidMap);

    [DllImport("Ntdsapi.dll", SetLastError = true)]
    public static extern void DsFreeSchemaGuidMap(IntPtr pGuidMap);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public class GUID
    {
        public uint Data1;
        public int Data2;
        public int Data3;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public byte[] Data4 = new byte[8];
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct DS_SCHEMA_GUID_MAP
    {
        public GUID guid;
        public uint guidType;
        public string pName;
    }

    [DllImport("ntdsapi.dll", CharSet = CharSet.Auto)]
    public static extern uint DsBind(
        IntPtr DomainControllerName,
        IntPtr DnsDomainName,
        ref IntPtr phDS);

    [DllImport("ntdsapi.dll", CharSet = CharSet.Auto)]
    public static extern uint DsBind(
        IntPtr DomainControllerName,
        String DnsDomainName,
        ref IntPtr phDS);

    [DllImport("ntdsapi.dll", CharSet = CharSet.Auto)]
    public static extern uint DsUnBind(IntPtr phDS);

    public static List<string> parseGuids(IntPtr guidMap, int numGuids, bool freePointer)
    {
        int typeSize = Marshal.SizeOf(typeof(DS_SCHEMA_GUID_MAP));
        List<string> guids = new List<string>();
        DS_SCHEMA_GUID_MAP[] schemaMap = new DS_SCHEMA_GUID_MAP[numGuids];
        IntPtr guidPointer = guidMap;

        for (int i = 0; i < numGuids; i++)
        {
            schemaMap[i] = (DS_SCHEMA_GUID_MAP)Marshal.PtrToStructure(
            new IntPtr
            (
                (long)guidPointer + i * typeSize
            ),
                typeof(DS_SCHEMA_GUID_MAP)
            );

            if(String.IsNullOrEmpty(schemaMap[i].pName)) {
                guids.Add("");
            } else {
                guids.Add(String.Copy(schemaMap[i].pName));
            }
        }

        if (freePointer)
        {
            DsFreeSchemaGuidMap(guidPointer);
        }

        return guids;
    }
}
'@
        }
    

        $dsHandle = [System.IntPtr]::Zero

        if(([String]::IsNullOrEmpty($Domain))) {
            $status = [Interop]::DsBind([System.IntPtr]::Zero, [System.IntPtr]::Zero, [ref]$dsHandle)
        } else {
            $status = [Interop]::DsBind([System.IntPtr]::Zero, $Domain, [ref]$dsHandle)
        }
        if($status -ne 0) {
            throw "Unable to bind to AD: $status"
        }
    }

    Process {
        if($InputObject -isnot [array]) {
            $InputObject = [guid[]]@(,$InputObject)
        }

        $GuidMap = [System.IntPtr]::Zero
        $status = [Interop]::DsMapSchemaGuids($dsHandle, $InputObject.Length, $InputObject, [ref]$GuidMap);

        if($status -eq 0) {
            $GuidMapping = [interop]::parseGuids($GuidMap, $InputObject.Length, $true)

            for($i=0; $i -lt $InputObject.Count; $i++) {
                New-Object PSObject -Property @{
                    Guid = $InputObject[$i]
                    Name = $GuidMapping[$i]
                }
            }
        } else {
            Write-Error "Error mapping schema guids: $status"
        }
    }


    End {
        if($dsHandle -ne [System.IntPtr]::Zero) {
            $status = [Interop]::DsUnbind($dsHandle)
        }
    }
}
