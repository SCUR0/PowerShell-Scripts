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

.PARAMETER NoFilter
  Skips filter that hides percentage spam from logs. Useful if you want to supervise the sync.

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
    [int]$Percent,
    [switch]$NoFilter
)


'#'*40+' '+(Get-Date)+' '+'#'*40 | out-file $LogPath -Append

if ($SyncSNAPRaid){
    $SyncArgs = @{}

    if ($NoFilter){
        $SyncArgs.NoFilter = $true
    }

    #run sync script
    try {
        &$SyncSNAPRaid -Force @SyncArgs -ErrorAction Stop
    }catch{
        if ($SendGmail){
            &$SendGmail -Subject "SnapRAID SCRUB FAILURE on $($env:COMPUTERNAME)" -Message "<pre>$($Error[0].Exception.Message)</pre>" -Html
        }
        exit 4
    }
}

if ($rxpcc){
    #PrimoCache pause cache
    Write-Output 'Pausing Primocache'
    &$rxpcc pause -a -s
}

$ScrubArgs = [System.Collections.ArrayList]@('scrub')
if ($Percent){
    $ScrubArgs.Add("-p $Percent") > $null
    $ScrubArgs.Add('-o 0') > $null
}

if ($NoFilter){
    &$Snapexe @ScrubArgs | Tee-Object $LogPath -Append
}else{
    &$Snapexe @ScrubArgs | select-string -Pattern '\d+%,\s\d+\sMB' -notmatch | Out-File $LogPath -Append 
}
$SRan = $?

if (!$SRan -and $SendGmail){
    &$SendGmail -Subject "SnapRAID SCRUB FAILURE on $($env:COMPUTERNAME)" -Message "<pre>$($Error[0].Exception.Message)</pre>" -Html
}

if ($rxpcc){
    #PrimoCache resume cache
    Write-Output 'Resuming Primocache'
    &$rxpcc resume -a -s
}