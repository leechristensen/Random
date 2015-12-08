<#
Author: Lee Christensen (@tifkin_)
Edited by: Josh M. Bryant (@FixTheExchange)
License: BSD 3-Clause
Required Dependencies: EWS API 2.2 https://www.microsoft.com/en-us/download/details.aspx?id=42951
Optional Dependencies: None
#>

Add-Type -Path 'C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll'

if(!$Creds)
{
    $Creds = Get-Credential
}
$emailAddress = $Creds.UserName
$password = $Creds.Password

$exchService = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService
$exchService.Credentials = New-Object Microsoft.Exchange.WebServices.Data.WebCredentials -ArgumentList $emailAddress, $password
#Autodiscover, there is no other, way to decide where you're mailbox is stored...
$exchService.AutodiscoverUrl($emailAddress, {$true})

$mbx = New-Object Microsoft.Exchange.WebServices.Data.Mailbox($emailAddress)

# Setup the search query
$searchFilterCollection = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+SearchFilterCollection([Microsoft.Exchange.WebServices.Data.LogicalOperator]::Or)
$searchFilter1 = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+ContainsSubstring([Microsoft.Exchange.WebServices.Data.ContactSchema]::ItemClass,"IPM.Rule.Version2.Message")
$searchFilterCollection.add($searchFilter1)

# Setup the search filter
# ptag property IDs and datatypes obtained from "[MS-OXPROPS]: Exchange Server Protocols Master Property List"
#   - https://msdn.microsoft.com/en-us/library/cc433490(v=exchg.80).aspx
$PidTagRuleMessageName = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x65EC, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String) # Rule name
$PidTagExtendedRuleMessageActions = new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x0E99, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary) # Binary blob that defines actions. Also the condition for "Start Application" rules
$PidTagExtendedRuleMessageCondition = new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x0E9A, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Binary) # 
$PidTagRuleMessageState = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x65E9, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer) # Defines whether rule is enabled


$PropertySet = new-object Microsoft.Exchange.WebServices.Data.PropertySet
#$PropertySet.Add([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
$PropertySet.Add([Microsoft.Exchange.WebServices.Data.ItemSchema]::ItemClass)
$PropertySet.Add($PidTagRuleMessageName)
$PropertySet.Add($PidTagExtendedRuleMessageActions)
$PropertySet.Add($PidTagExtendedRuleMessageCondition)
$PropertySet.Add($PidTagRuleMessageState)

$itemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(100,0,[Microsoft.Exchange.WebServices.Data.OffsetBasePoint]::Beginning)
$itemView.Traversal = [Microsoft.Exchange.WebServices.Data.ItemTraversal]::Shallow
$itemView.OrderBy.add([Microsoft.Exchange.WebServices.Data.ItemSchema]::DateTimeReceived,[Microsoft.Exchange.WebServices.Data.SortDirection]::Ascending)
$itemView.PropertySet = $PropertySet
$itemView.Traversal = [Microsoft.Exchange.WebServices.Data.ItemTraversal]::Associated

$rfRootFolderID = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox, $emailAddress)
$rfRootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($exchService,$rfRootFolderID)

# Do the search
$FindResults = $exchService.FindItems([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox, $searchFilterCollection, $itemView)


function Get-ExtendedProperty
{
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Exchange.WebServices.Data.Item]
        $Item,

        # Param2 help descriptio
        [ValidateNotNullOrEmpty()]
        [Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition]
        $Property
    )

    $Value = $null
    $Succeeded = $Item.TryGetProperty($Property, [ref]$Value)

    if($Succeeded)
    {
        $Value
    }
    else
    {
        Write-Warning ("Could not get value for " + [System.Convert]::ToString($Property.Tag,16))
    }
}

$Rules = @()
foreach($Item in $FindResults.Items)
{
    $Rules += New-Object PSObject -Property @{
        Name      = Get-ExtendedProperty -Item $Item -Property $PidTagRuleMessageName
        Action    = Get-ExtendedProperty -Item $Item -Property $PidTagExtendedRuleMessageActions
        Condition = Get-ExtendedProperty -Item $Item -Property $PidTagExtendedRuleMessageCondition
        State     = Get-ExtendedProperty -Item $Item -Property $PidTagRuleMessageState
    }
}

$Rules
