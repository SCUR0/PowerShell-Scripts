#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Updates Plex running as service.
  
 .PARAMETER ServiceName
  Name of service hosting plex media server.

.PARAMETER User
  User the service is running as.

.PARAMETER UpdateDir
  Folder where updates are stored if not using defaults

.DESCRIPTION
  If plex is running as service, a script is needed to update.
  This script will update that service when ran as another user.
  IMPORTANT: Change directory where plex stores updates as well as the name of plex service!
#>
[cmdletbinding()]
param (
	$ServiceName="plex",
	$User="media",
	$UpdateDir
)

if (!$UpdateDir){
	#Default download locations
	if ($User -eq "Local Service"){
		$UpdateDir = "$($env:windir)\system32\config\systemprofile\AppData\Local\Plex Media Server\Updates"
	}else{
		$UpdateDir = "C:\Users\$User\AppData\Local\Plex Media Server\Updates"
	}
}

#looks for newest folder in update directory
$UpdateDir2 = Get-ChildItem -Path $UpdateDir | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$latestupdate = Get-ChildItem -Path "$($UpdateDir2.pspath)\packages"| Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestupdate){
	Write-Host "Stopping Plex Service..." -ForegroundColor DarkYellow
	try{
		Get-Service $ServiceName | Foreach {
			$_.DependentServices | stop-Service -PassThru
		}
		Stop-Service $ServiceName -ErrorAction Stop -PassThru
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
		Get-Service $ServiceName | Foreach {
			$_.DependentServices | start-Service -PassThru
		}
		Start-Service $ServiceName -PassThru
		#Delete Update
		Write-Output "Deleting leftover update files"
		Remove-Item "$UpdateDir/*" -Recurse
	}
}else{
	Write-Error "No update file found in $UpdateDir. Verify folder is correct."
}