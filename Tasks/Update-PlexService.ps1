#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Updates Plex running as service.

.DESCRIPTION
  If plex is running as service, a script is needed to update.
  This script will update that service when ran as another user.
  IMPORTANT: Change directory where plex stores updates as well as name of plex service!
#>
[cmdletbinding()]
param ()

#Change to directory that updates are stored. It is usually in local appdata of user the service runs as
$updatedir = "C:\Users\plex\AppData\Local\Plex Media Server\Updates"
$PlexServiceName="Plex Media Server"

#looks for newest folder in update directory
$updatedir2 = Get-ChildItem -Path $updatedir | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$latestupdate = Get-ChildItem -Path "$($updatedir2.pspath)\packages"| Sort-Object LastAccessTime -Descending | Select-Object -First 1

Write-Host "Stopping Plex Service..." -ForegroundColor Red
try{
    Get-Service $PlexServiceName | Stop-Service
}catch{
    Write-Warning ("Plex service was unable to be stopped. Verify you have the correct service name in the script and that "+
    "the script was run as administrator.")
    $PlexFail=$true
}

if (!$PlexFail){
    Write-Output "Installing update..."
    Start-Process $latestupdate.PSPath -ArgumentList "/install /passive /norestart" -Wait

    #Deletes registry keys stored for user running script (not the account for service)
    If ($(Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Plex Media Server" -ErrorAction SilentlyContinue)) {
        Write-Host "Plex startup registry keys found. Removing." -ForegroundColor Yellow
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\" -Name "Plex Media Server" -Force
    }
    Write-Host "Starting Plex Service..." -ForegroundColor green
    Get-Service $PlexServiceName | Start-Service
}
