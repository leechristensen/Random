# Modified from https://github.com/EmpireProject/Empire/blob/master/lib/modules/powershell/management/zipFolderPath.py
function New-ZipFolder
{
	[CmdletBinding()]
    param(
		[Parameter(Position=0, Mandatory=$true)]
		[string]
		$FolderPath,
		
		[Parameter(Position=1, Mandatory=$true)]
		[string]
		$ZipPath
	)
	
    if (-not (Test-Path $FolderPath)) {
        throw "Target FolderPath $FolderPath doesn't exist."
    }
    if (test-path $ZipPath -ErrorAction SilentlyContinue) { 
        throw "Zip file already exists at $ZipPath"
    }
    $Directory = Get-Item $FolderPath
    Set-Content $ZipPath ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
    (dir $ZipPath).IsReadOnly = $false
    $ZipPath = resolve-path $ZipPath
    $ZipFile = (new-object -com shell.application).NameSpace($ZipPath)
    $ZipFile.CopyHere($Directory.FullName, 1044)
    "FolderPath $FolderPath zipped to $ZipPath"
}
