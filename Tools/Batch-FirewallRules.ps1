<#
.SYNOPSIS
    Add firewall rules for groups of IPs

.DESCRIPTION
	Use text file of IP ranges to create firewall rules. Check https://www.ipdeny.com/ipblocks/

.PARAMETER InputFile
	Text file of IP ranges

.PARAMETER Direction
	Firewall traffic direction. Defaults to inbound.

.PARAMETER RuleName
	Name to use for firewall rules. A number will be added after. Defaults to text file name if not provided.

.PARAMETER Protocol
	TCP or UDP. Defaults to TCP.

.PARAMETER Ports
	Firewall rule ports. Do not use quotes. Seperate multiple values with comma.
#>
    
param (
    [Parameter(Mandatory=$True)]
    $InputFile,
    $Direction = "inbound",
    $RuleName,
	$Protocol="tcp", 
    [Parameter(Mandatory=$True)]
    $Ports)

# Get input file and set the name of the firewall rule.
$File = get-item $InputFile -ErrorAction SilentlyContinue # Sometimes rules will be deleted by name and there is no file.
if (!$?){
    Write-Error "Cannot find $InputFile"
    exit
} 
if (!$RuleName){
    $RuleName = $File.basename + "-$Protocol"
}

# Description will be seen in the properties of the firewall rules.
$Description = "Rule created by script on $(get-date -Format "MM-d-y")."

# Check for existing rules
$ExistingRules = Get-NetFirewallRule | Where-Object DisplayName -Like "$RuleName*"

if ($ExistingRules){
    $ExistingRules | Remove-NetFirewallRule
}
# Create array of IP ranges. Any line that doesn't start like an IPv4/IPv6 address is ignored.
$Ranges = get-content $File | where {($_.trim().length -ne 0) -and ($_ -match '^[0-9a-f]{1,4}[\.\:]')} 
if (!$?) {
    Write-Error "Could not parse $File"
    exit
} 
$LineCount = $Ranges.count
if ($LineCount -eq 0) {
    Write-Warning "Zero IP addresses found"
    exit
} 

# Create rules with a limit of ranges per rule (due to windows limits)
$MaxRangesPerRule = 200
$End = $MaxRangesPerRule
for ($i = $Start = 1; $Start -le $LineCount; $($i++; $Start += $MaxRangesPerRule; $End += $MaxRangesPerRule)){
    $iCount = $i.tostring().padleft(3,"0")  # Used in name of rule, e.g., BlockList-#042.
    
    if ($End -gt $LineCount) {
        $End = $LineCount
    } 
    $TextRanges = $Ranges[$($Start - 1)..$($End - 1)]

    Write-verbose "Creating an  inbound firewall rule named '$RuleName-#$iCount' for IP ranges $Start - $End" -Verbose

    New-NetFirewallRule -DisplayName "$RuleName-#$iCount" -Direction $Direction -LocalPort $Ports -RemoteAddress $TextRanges -Protocol $Protocol -Action Allow -Description $Description | Out-Null
}