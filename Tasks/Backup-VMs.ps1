<#
.SYNOPSIS
  Copies all VMs to directory.

.DESCRIPTION
  The script will copy all VMs to a directory of your choice.
  This is usefull for backup.

.PARAMETER ExportPath
  If left empty will use D:\Backup\VMs, set to your folder for vm backup or edit default in script.

.PARAMETER 7ZipExe
  Default path for 7zip executable to archive
#>
[cmdletbinding()]
param (
    $ExportPath="D:\Backup\VMs",
    $7ZipExe="C:\Program Files\7-Zip\7z.exe"
)

$VMs=Get-VM | Where Name -notlike "*test*"
$VMCount=$VMs.count
$CurrentCount=0
$CompletedVMs = @()
foreach ($VM in $VMs) {
    $TempPath="$ExportPath\$($VM.Name).temp"
    $MoveFail=$null
    $RemoveFail=$null
    $Percent=[math]::Round($CurrentCount/$VMCount*100)
    Write-Progress -Activity "Backing up VMs" -Status "Exporting $($VM.Name) $($CurrentCount+1)/$VMCount" -PercentComplete $Percent -Id 1
    if (Test-Path -Path $ExportPath\$($VM.Name)) {
        Write-Verbose "Previous backup found, moving temp."
        if (!(Test-Path $TempPath)){
            try{
                Rename-Item -Path $ExportPath\$($VM.Name) -NewName $TempPath -ErrorAction Stop
            }catch{
                $MoveFail=$true
            }
        }else{
            Write-Verbose "Temp folder already found for $($VM.Name). Deleting"
            Remove-Item -Path $TempPath -Force -Recurse -Confirm:$false
            try{
                Rename-Item -Path $ExportPath\$($VM.Name) -NewName $TempPath -ErrorAction Stop
            }catch{
                $MoveFail=$true
            }
        }
    }
    if (!$MoveFail){
        write-verbose "Exporting VM: $($VM.Name)."
        try{
            Export-VM -Name $VM.Name -Path $ExportPath -ErrorAction Stop
        }catch{
            Write-Warning "Export failed, reverting backup."
            Rename-Item -Path $TempPath -NewName "$ExportPath\$($VM.Name)"
            $ExportFail = $true
        }
        if (!$ExportFail){
            Write-Verbose "Export successful. Deleting old backup."
            Remove-Item -Path $TempPath -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
            $CompletedVMs += $VM.Name
        }
    }
    $CurrentCount++
}
Write-Progress -Activity "Backing up VMs" -Completed

if (Test-Path $7ZipExe){
    Write-Verbose "Compressing Exports"
    cd $ExportPath
    foreach ($CompletedVM in $CompletedVMs){
        Write-Verbose "Compressing $CompletedVM"
        .$7ZipExe a "VMs-$(Get-Date -Format "yy-MM")" $CompletedVM -mmt4
    }
}else{
    Write-Output "7zip can be used to compress and archive VMs. Install 7zip or use custom install path in launch arguments."
}