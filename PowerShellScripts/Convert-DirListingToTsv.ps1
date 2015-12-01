<#
.Synopsis
Parses the out the output the command prompt's "dir" command into a tab delimited file. 

Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

.DESCRIPTION
Parses the out the output the command prompt's "dir" command into a tab delimited file.
The file can then be searched or sorted to identify recently accessed files.  Useful
in certain scenarios where the "dir" command is faster than Get-ChildItem.

.EXAMPLE
cmd.exe /c dir /s /a \\fileshare\allusers > files.txt; Convert-DirListingToTsv -InputFile .\files.txt -OutputFile .\files.csv

#>
function Convert-DirListingToTsv
{
    [CmdletBinding()]
    Param
    (
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
    [string]
    $InputFile,

    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $OutputFile
    )
    
    Begin
    {
        $FileStream = New-Object System.IO.StreamReader -Arg $InputFile
        $CurrentDirectory = ""
        "" | Out-File $OutputFile
    }
    Process
    {
        $lines = [System.IO.File]::ReadLines($InputFile)

        ForEach($line in $lines)
        {
            # Are we listing a new directory?
            if($line -match "^ Directory of (.*)$")
            {
                $CurrentDirectory = $Matches[1]
                continue
            }
            
            # Parse the file
            try
            {
                $Date = $line.Substring(0,20)
                $Date = [datetime]::ParseExact($Date, "MM/dd/yyyy  hh:mm tt", $null)

                $filename = $line.Substring(39)

                if($filename -eq "." -or $filename -eq "..") {
                    continue;
                }

                $NewLine = $Date.ToString() + "`t" + $CurrentDirectory + "\" + $filename
                $NewLine | Out-File -Append $OutputFile
            }
            catch
            {
                # Meh...
                continue
            }
        }
    }
    End
    {
        $FileStream.close()
    }
}
