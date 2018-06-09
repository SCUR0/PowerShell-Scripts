#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Updates Plex running as service.

.DESCRIPTION
  If plex is running as service, a script is needed to update.
  This script will update that service when ran as another user.
  IMPORTANT: Change directory where plex stores updates as well a name of plex service!
#>
[cmdletbinding()]
param ()

#Change to directory that updates are stored. It is usually in local appdata of user the service runs as
$updatedir = "C:\Users\plex\AppData\Local\Plex Media Server\Updates"
$PlexServiceName="plex"

#looks for newest folder in update directory
$updatedir2 = Get-ChildItem -Path $updatedir | Sort-Object LastAccessTime -Descending | Select-Object -First 1
$latestupdate = Get-ChildItem -Path "$($updatedir2.pspath)\packages"| Sort-Object LastAccessTime -Descending | Select-Object -First 1

Write-Host "Stopping Plex Service..." -ForegroundColor DarkYellow
try{
    Get-Service $PlexServiceName | Foreach {
        $_.DependentServices | stop-Service -PassThru
    }
    Stop-Service $PlexServiceName -ErrorAction Stop -PassThru
}catch{
    Write-Error $Error
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
    Get-Service $PlexServiceName | Foreach {
        $_.DependentServices | start-Service -PassThru
    }
    Start-Service $PlexServiceName -PassThru
    #slight pause to show output before exit
    Start-Sleep -s 2
}else{
    #error occured. keep console up to show error
    pause
}
