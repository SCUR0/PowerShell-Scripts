<#
.SYNOPSIS
  Powershell initiated snapraid sync.

.PARAMETER LogPath
  Check default as an example for dates

.PARAMETER Snapexe
  Path to location of snapraid executable

.PARAMETER SendGmail
  Path of Send-Gmail.ps1 script #Check Tools\Send-Gmail.ps1

.PARAMETER NoFilter
  Skips filter that hides percentage spam from logs. Useful if you want to supervise the sync.

.PARAMETER Force
  Skips diff check

.DESCRIPTION
  Runs SNAPRaid sync only if differences are found. Errors are emailed to notify sync issues.
#>

[cmdletbinding()]
param(
    [string]$LogPath   = "C:\Logs\SnapRaid\$(get-date -Format 'yy-M-dd')-SnapRaid-SYNC.txt",
    [string]$Snapexe   = 'C:\Program Files\snapraid\snapraid.exe',
    [string]$SendGmail,
    [switch]$NoFilter,
    [switch]$Force
)


'#'*40+' '+(Get-Date)+' '+'#'*40 | out-file $LogPath -Append

#verify snapraid isn't already running
$SnapProcess = Get-Process | Where-Object {$_.Name -eq 'snapraid'}
if ($SnapProcess){
    $Output = 'Snapraid is already running. Exiting'
    Write-Error $Output 
    $Output | out-file $LogPath -Append
    exit 4
}

#check for differences
$DiffOutput = .$Snapexe diff
Write-Output $DiffOutput
if ($DiffOutput -like '*No differences' -and (!$Force)){
    'No differences' | out-file $LogPath -Append
    exit
}else{
    if ($Force){
        $Output = 'Force switch used'
        Write-Output $Output
        $Output| out-file $LogPath -Append
    }
    $DiffOutput | out-file $LogPath -Append
}

&$Snapexe touch
if ($NoFilter){
    &$Snapexe sync --error-limit 1 | Tee-Object $LogPath -Append
}else{
    &$Snapexe sync --error-limit 1 | select-string -Pattern '\d+%,\s\d+\sMB' -notmatch | out-file $LogPath -Append
}
$SRan = $?
if (!$SRan -and $SendGmail){
    .$SendGmail -Subject "SnapRAID SYNC FAILURE on $($env:COMPUTERNAME)" -Message "<pre>$($Error[0].Exception.Message)</pre>" -Html
}
