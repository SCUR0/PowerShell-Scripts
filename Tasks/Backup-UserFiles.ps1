<#
.SYNOPSIS
    Copies user files to google drive.

.PARAMETER RegPath
    Registry path used to track whether the script has run before

.PARAMETER GDPath
    Google drive destination path where backups are stored
#>

[CmdletBinding()]
param (
    $RegPath = "HKCU:\Software\AdminScripts\GD-UserBackup",
    $GDPath = "G:\My Drive\GDBackup\"
)

#Terminate if google drive is not available
if (!(Test-Path "G:\My Drive" -ErrorAction SilentlyContinue)){
    Write-Warning "Google file stream is not currently accessible. Exiting backup."
    exit
}

#Check if folder exists
if (!(Test-Path $GDPath)){
    New-Item $GDPath -ItemType Directory | Out-Null
    #hide folder on file stream
    $F = Get-Item $GDPath
    $F.Attributes+="Hidden"
}

#Check if first run
if (!(Test-Path $RegPath)){
    #First run
    Write-Verbose "First run detected. Checking folders" -Verbose
    if (Test-Path "$GDPath\$Env:COMPUTERNAME"){
        #old backup found
        if (Test-Path "$GDPath\$Env:COMPUTERNAME-OLD"){
            #delete old folder
            Remove-Item "$GDPath\$Env:COMPUTERNAME-OLD" -Recurse -Force
        }
        #Keep old data incase of reimage and script is ran before data is copied off
        Write-Verbose "Old data found on first run. Keeping old data as OLD" -Verbose
        Rename-Item "$GDPath\$Env:COMPUTERNAME" "$GDPath\$Env:COMPUTERNAME-OLD"     
    }
    New-Item "$GDPath\$Env:COMPUTERNAME" -ItemType Directory | Out-Null
    New-Item -Path $RegPath -Force | Out-Null
}

########## Start Backup Process ############

#Grab library paths
$DocumentsLibrary = ([Environment]::GetFolderPath("MyDocuments"))
$DesktopLibrary = ([Environment]::GetFolderPath("Desktop"))

#Skip backup if libraries have been changed to google drive
if ($DocumentsLibrary -notlike "G:\My Drive*"){
    robocopy $DocumentsLibrary "$GDPath\$Env:COMPUTERNAME\Documents" /MIR /FFT /Z /XJF /XJD /XA:H /R:3 /W:60 /MT:4
}
if ($DesktopLibrary -notlike "G:\My Drive*"){
    robocopy $DesktopLibrary "$GDPath\$Env:COMPUTERNAME\Desktop" /MIR /FFT /Z /XJF /XJD /XA:H /R:3 /W:60 /MT:4
}
#Find Bookmarks
$ChromeBookmarks = Get-ChildItem -Path "$env:LOCALAPPDATA\Google\Chrome\User Data" -Filter Bookmarks -Recurse -ErrorAction SilentlyContinue -Force |`
                                 where {$_.Directory -notlike "*SnapShots*"}
Foreach ($Bookmark in $ChromeBookmarks){
    $PDir = ($Bookmark.Directory -split "\\")[-1]
    $Source = $Bookmark.Directory
    $Destination = "$GDPath\$Env:COMPUTERNAME\Chrome\$PDir"
    $File = $Bookmark.Name
    robocopy $Source $Destination $File /R:3 /W:60
}
