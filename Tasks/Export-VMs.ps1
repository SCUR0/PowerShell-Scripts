<#
.SYNOPSIS
  Copies all VMs to directory.

.DESCRIPTION
  The script will copy all VMs to a directory of your choice.
  This is usefull for backup.
#>
[cmdletbinding()]
param ()

#change path to location you want the copies stored.
$ExportPath="D:\Backup\VMs"
$VMs=Get-VM
foreach ($VM in $VMs) {
    $RemoveFail=$null
    if (Test-Path -Path $ExportPath\$($VM.Name)) {
        Write-Verbose "Previous backup found, moving temp."
        try{
            Rename-Item -Path $ExportPath\$($VM.Name) -NewName "$ExportPath\$($VM.Name).temp"
        }catch{
            $MoveFail=$true
        }
    } 
    if (!$MoveFail){
        write-verbose "Exporting VM: $($VM.Name)."
        try{
            Export-VM -Name $VM.Name -Path $ExportPath
        }catch{
            $ExportFail = $true
            Write-Warning "Export failed, reverting backup."
            Rename-Item -Path "$ExportPath\$($VM.Name).temp" -NewName "$ExportPath\$($VM.Name)"

        }
        if (!$ExportFail){
            Write-Verbose "Export successful. Deleting old backup."
            Remove-Item -Path "$ExportPath\$($VM.Name).temp" -Force -Recurse -Confirm:$false
        }
    }
}
