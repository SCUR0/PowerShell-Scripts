[CmdletBinding()]
param (
 [string]$Search
)

#ask user if left blank
if (!$Search){
    $Search = Read-Host "Search string"
}
 
$DomainName = $env:USERDNSDOMAIN 
 
#pull all policies 
Write-Host "Loading GPOs" 
Import-Module GroupPolicy
$GPOs = Get-GPO -All -Domain $DomainName 

#search using xml output
Write-Host "Starting search..." 
foreach ($GPO in $GPOs) { 
    $report = Get-GPOReport -Guid $GPO.Id -ReportType Xml
    if ($report -match [Regex]::Escape($Search)) { 
        write-host "********** Match found in: $($GPO.DisplayName) **********" -foregroundcolor "Green"
        write-host (($report | Select-String -Pattern ".+$([Regex]::Escape($Search)).+").Matches.Value).Trim()
    }
}