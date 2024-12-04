<#
.SYNOPSIS
  Remove dates from FreeFileSync Versions

.DESCRIPTION
  This script is for removing dates from the versioning from FreeFileSync.
  This requires FreeFileSync to use "Time Stamp [File] versioning".
  DO NOT run from your versioning folder. Copy your versions to another folder.

.PARAMETER FolderPath
  Path to folder that has the files you want to remove dates from.

.Notes
  FreeFileSync is an open source backup software. It is available for Mac, Linux, and Windows.
  https://freefilesync.org/
#>

[cmdletbinding()]
param (
    [Parameter(Mandatory)]
    [string]$FolderPath
)

#Get all files in the folder
$Files = Get-ChildItem -Path $FolderPath -Recurse -File | Where-Object {$_.Name -notlike '*.lnk' -and $_.Name -match ' \d{4}-\d{2}-\d{2} \d{6}.*'} | Sort-Object $_.CreationTime -Descending

#Process each file
foreach ($File in $Files) {
    #Remove date from file name
    $FinalName = $BaseName = $File.Name -replace ' \d{4}-\d{2}-\d{2} \d{6}.*', ""

    #test for duplicate
    $i = 1
    While (Test-Path "$($File.Directory)\$FinalName"){
        $i++
        $FinalName = "$BaseName($i)"
    }

    #Rename the file
    Rename-Item -LiteralPath "$($File.FullName)" -NewName $FinalName -ErrorAction Stop
}
Write-Output "$($Files.Count) file names updated"