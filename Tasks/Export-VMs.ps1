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
    if (Test-Path -Path $ExportPath\$($VM.Name)) {
        Write-Verbose "Previous backup found, deleting."
        Remove-Item -Path $ExportPath\$($VM.Name) -Force -Recurse -Confirm:$false
    } 
    Export-VM -Name $VM.Name -Path $ExportPath
}
