<#
.SYNOPSIS
  Audit Logins

.DESCRIPTION
  This script is used for quick audits of logins for RDP or SMB.
  NOTE - Login auditing needs to be enabled.

.PARAMETER StartDate
  Amount of days to start from default is a week

.PARAMETER LoginType
  10 = remote login, 3 = network
#>

[CmdletBinding()]
Param(
    [int]$StartDays = 7,
    [int]$LoginType = 10
)
$StartDate = (get-date).AddDays(-$StartDays)
$CollectionObject = @()
$LogonEvents = Get-Eventlog -LogName Security -after $StartDate | where {$_.eventID -eq 4624 }

#Go through event log and add to collection object

foreach ($e in $LogonEvents){
    $EventObject = New-Object -TypeName psobject
    if (($e.EventID -eq 4624 ) -and ($e.ReplacementStrings[8] -eq $LoginType) -and ($e.TimeGenerated -ne $CollectionObject[-1].Time)){
        #write-host "Type: Remote Logon`tDate: "$e.TimeGenerated "`tStatus: Success`tUser: "$e.ReplacementStrings[5] "`tWorkstation: "$e.ReplacementStrings[11] "`tIP Address: "$e.ReplacementStrings[18]
        $EventObject | Add-Member -MemberType NoteProperty -Name Time -Value $e.TimeGenerated
        $EventObject | Add-Member -MemberType NoteProperty -Name User -Value $e.ReplacementStrings[5]
        $EventObject | Add-Member -MemberType NoteProperty -Name HostName -Value $e.ReplacementStrings[11]
        $EventObject | Add-Member -MemberType NoteProperty -Name IP -Value $e.ReplacementStrings[18]
        $CollectionObject += $EventObject
    }
}

Write-Output $CollectionObject