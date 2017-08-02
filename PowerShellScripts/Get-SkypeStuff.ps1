<#
Author: Lee Christensen (@tifkin_)
License: BSD 3-Clause
Required Dependencies: Microsoft Lync SDK

Heavily based off of Karl Fosaaen's (@kfosaaen) original script.  See
 - https://github.com/NetSPI/PowerShell/blob/master/PowerSkype.ps1
 - https://blog.netspi.com/attacking-federated-skype-powershell/
#>


if (-not (Get-Module -Name Microsoft.Lync.Model))
{
    $LyncSdkPath = "${env:ProgramFiles(x86)}\Microsoft Office 2013\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll"
    $VisualStudioPath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\Extensions\Microsoft\CodeSense\Framework\Microsoft.Lync.Model.dll"

    if(Test-Path -Path $LyncSdkPath -ErrorAction SilentlyContinue) {
        Import-Module $LyncSdkPath
    } elseif(Test-Path -Path $VisualStudioPath -ErrorAction SilentlyContinue) {
        Import-Module $VisualStudioPath
    } else {
        throw "Unable to find the Microsoft.Lync.Model assembly.  Please make sure it is loaded."
    }
}

Function Get-SkypeStatus{
<#
    .SYNOPSIS
        Gets the current status of valid federated Skype users.
    .PARAMETER email
        The email address to lookup.   
    .PARAMETER inputFile
        The file of email addresses to lookup. 
    .PARAMETER outputFile
        The CSV file to write the table to.
    .PARAMETER attempts
        The number of times to check the status (Default=1).          
    .PARAMETER delay
        The amount of delay to set between users read from a file.          		
    .EXAMPLE
        PS C:\> Get-SkypeStatus -email test@example.com 

		Email         : test@example.com
		Title         : Chief Example Officer
		Full Name     : Testing McTestface
		Status        : Available
		Out Of Office : False

#>


    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,
        HelpMessage="Email address to verify the status of.")]
        [string[]]$Email
    )

    # Connect to the local Skype process
    try
    {
        $client = [Microsoft.Lync.Model.LyncClient]::GetClient()
    }
    catch
    {
        throw "You need to have Skype open and signed in first"
    }

    $Contacts = New-Object System.Collections.ArrayList
    
    #Get a remote contact
    
    foreach($e in $Email) {
        try
        {
            $Res = $client.ContactManager.GetContactByUri($e)
            $null = $Contacts.Add($Res)
        }
        catch
        {
            Write-Warning "Failed to lookup Contact $e"
        }
    }

    # Create a conversation
    $Conversation = $client.ConversationManager.AddConversation()
    $Contacts | ForEach-Object { $null = $Conversation.AddParticipant($_) }

    # Reserve fields 4 and 5 would often cause errors (depending on the account)
    $Types = New-Object 'System.Collections.Generic.List[Microsoft.Lync.Model.ContactInformationType]'
    $ContactInformationType = [System.Enum]::GetNames([Microsoft.Lync.Model.ContactInformationType]) | Sort-Object | Where-Object {$_ -notmatch 'Reserved(4|5)'} | ForEach-Object{$Types.Add($_)}
        
    foreach($Contact in $Contacts) {
        $Output = [ordered]@{}
        try { 
            sleep 1
            $Val = $contact.GetContactInformation($Types)

            $Val.ForEach({
                $Output[$_.Key] = $_.Value
            })

            New-Object PSObject -Property $Output
        } catch {
            Write-Error $_
        }
    }

    $null = $Conversation.End()
}
