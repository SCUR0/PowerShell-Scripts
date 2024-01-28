<#
.SYNOPSIS
  Powershell initiated snapraid scrub.

.PARAMETER LogPath
  Check default as an example for dates

.PARAMETER Snapexe
  Path to location of snapraid executable

.PARAMETER SyncSNAPRaid
  Path to Sync-Snapraid.ps1 script. #Check Tasks\Sync-Snapraid.ps1
  
.PARAMETER SendGmail
  Path of Send-Gmail.ps1 script #Check Tools\Send-Gmail.ps1

.PARAMETER rxpcc
  This is for primocache freeze and resume cache

.PARAMETER Percent
  Forces a minimum percent to scrub

.DESCRIPTION
  Runs SNAPRaid sync and then a scrub. Notifies if errors are found
#>

[cmdletbinding()]
param(
    [string]$LogPath      = "C:\Logs\SnapRaid\$(get-date -Format 'yy-M-dd')-SnapRaid-SCRUB.txt",
    [string]$Snapexe      = 'C:\Program Files\snapraid\snapraid.exe',
    [string]$SyncSNAPRaid,
    [string]$SendGmail,
    [string]$rxpcc        = 'C:\Program Files\PrimoCache\rxpcc.exe',
    [int]$Percent
)


'#'*40+' '+(Get-Date)+' '+'#'*40 | out-file $LogPath -Append

if ($SyncSNAPRaid){
    #run sync script
    &$SyncSNAPRaid -Force
}

if ($rxpcc){
    #PrimoCache pause cache
    &$rxpcc pause -a -s
}

if ($Percent){
    $SOutput = &$Snapexe  -p $Percent -o 0 scrub
}else{
    $SOutput = &$Snapexe scrub
} 
$SRan = $?
Write-Output $SOutput
$SOutput | select-string -Pattern '\d+%,\s\d+\sMB' -notmatch | Out-File $LogPath -Append

if (!$SRan -and $SendGmail){
    &$SendGmail -Subject "SnapRAID SCRUB FAILURE on $($env:COMPUTERNAME)" -Message "<pre>$SOutput</pre>" -Html
}

if ($rxpcc){
    #PrimoCache resume cache
    &$rxpcc resume -a -s
}