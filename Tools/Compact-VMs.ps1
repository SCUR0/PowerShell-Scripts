<#
.SYNOPSIS
  Compacts all VHDs

.DESCRIPTION
  Script will shutdown and then compact all VHDs for VMs
  This is used for dynamic disks.

.Parameter Name
  Name of VM. If left blank the script will compact all VMs.

#>
[cmdletbinding()]
param (
    $Name
)
if ($Name){
    $VMs = Get-VM -Name $Name
}else{
    $VMs = Get-VM
}
$VMCount=$VMs.count
$CurrentCount=0
foreach ($VM in $VMs) {
    #get vm state if already shutdown
    $Sate = $VM.State
    if ($VM.State -ne "off"){
        Write-Verbose "Shutting VM $($VM.name) down" -Verbose
        $VM | Stop-VM
    }
    $VHDDisks = $VM | Get-VMHardDiskDrive

    foreach ($Drive in $VHDDisks){
        $StartSize = [math]::truncate(($Drive | Get-VHD).FileSize/ 1MB)
        Write-Verbose "Compacting $($Drive.path)" -Verbose
        $Drive | Optimize-VHD -Mode Full
        $EndSize = [math]::truncate(($Drive | Get-VHD).FileSize/ 1MB)
        $SpaceSaved = $StartSize - $EndSize
        Write-Verbose "Drive size reduced by $($SpaceSaved)MB" -Verbose
    }
    
    if ($Sate -eq "Running"){
        #Start VM if it had already been running
        Write-Verbose "Starting VM $($VM.name)" -Verbose
        $VM | Start-VM
    }
}