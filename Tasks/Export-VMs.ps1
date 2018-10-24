<#
.SYNOPSIS
  Copies all VMs to directory.

.DESCRIPTION
  The script will copy all VMs to a directory of your choice.
  This is usefull for backup.

.PARAMETER ExportPath
  If left empty will use D:\Backup\VMs, set to your folder for vm backup or edit default in script.
#>
[cmdletbinding()]
param (
    $ExportPath="D:\Backup\VMs"
)

$VMs=Get-VM
$VMCount=$VMs.count
$CurrentCount=0
foreach ($VM in $VMs) {
    $Percent=[math]::Round($CurrentCount/$VMCount*100)
    Write-Progress -Activity "Backing up VMs" -Status "Exporting $($VM.Name) $($CurrentCount+1)/$VMCount" -PercentComplete $Percent -Id 1
    $RemoveFail=$null
    if (Test-Path -Path $ExportPath\$($VM.Name)) {
        Write-Verbose "Previous backup found, moving temp."
        try{
            Rename-Item -Path $ExportPath\$($VM.Name) -NewName "$ExportPath\$($VM.Name).temp" -ErrorAction Stop
        }catch{
            $MoveFail=$true
        }
    } 
    if (!$MoveFail){
        write-verbose "Exporting VM: $($VM.Name)."
        try{
            Export-VM -Name $VM.Name -Path $ExportPath -ErrorAction Stop
        }catch{
            Write-Warning "Export failed, reverting backup."
            Rename-Item -Path "$ExportPath\$($VM.Name).temp" -NewName "$ExportPath\$($VM.Name)"
            $ExportFail = $true
        }
        if (!$ExportFail){
            Write-Verbose "Export successful. Deleting old backup."
            Remove-Item -Path "$ExportPath\$($VM.Name).temp" -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    $CurrentCount++
}
Write-Progress -Activity "Backing up VMs" -Completed
