<#
Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

Based off of http://wannemacher.us/?p=225
#>

function Compress-File
{
    param
    (
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=0)]
    [String]
    $Path,

    [Parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true,
               Position=1)]
    [String]
    $DestinationPath = $($Path + “.gz”)
    )
    
    if ((Test-Path $Path -ErrorAction SilentlyContinue))
    {
        try
        {
            Write-Verbose “Compressing $Path to $DestinationPath.”
    
            $Input = New-Object System.IO.FileStream $Path, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read);
            $Output = New-Object System.IO.FileStream $DestinationPath, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
            $GzipStream = New-Object System.IO.Compression.GzipStream $Output, ([IO.Compression.CompressionMode]::Compress)

            $BufferSize = 1024*1024*64
            $Buffer = New-Object byte[]($BufferSize);
        
            while($true)
            {
                $Read = $Input.Read($Buffer, 0, $BufferSize)
            
                if ($Read -le 0)
                {
                    break;
                }
            
                $GzipStream.Write($Buffer, 0, $Read)
            }
        }
        finally
        {
            if($BzipStream) {
                $BzipStream.Close()
            }
            if($Output) {
                $Output.Close()
            }
            if($Input) {
                $Input.Close()
            }
        }
    }
}