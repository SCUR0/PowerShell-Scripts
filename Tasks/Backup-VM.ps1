<#
.SYNOPSIS
  Backup and compress VM

.DESCRIPTION
  Script will copy VM(s) to another directory as well as compress with 7zip if installed.
  This is usefull for simple backups of VMs.

.PARAMETER Name
  VM Name(s) to backup. If left empty all VMs will be backed up.

.PARAMETER ExportPath
  Path for exports. If empty will export to current path.

.PARAMETER Exclude
  List of VMs to not include in export if Name parameter is left default (all VMs).

.PARAMETER ZipExe
  Path for 7Zip. If left empty uses the default path for 7zip executable.
  If 7zip is not found the script will export to folders uncompressed.

.PARAMETER Password
  7zip Encryption password

.PARAMETER FirstDiskOnly
  If set only the first disk of the VM will be exported. Other disks will be removed before export and added back after.
  The VM will be shutdown if running and started again after export.

.PARAMETER ProcessCap
  Used to limit the number of concurrent 7zip processes. Default is 2.

.PARAMETER 7zThreads
  Number of threads to use for 7zip compression. Default is 4 for a conservative value. 8-16 is recommended if you have high multi thread support.

.EXAMPLE
  Backup-VM.ps1 -ExportPath "J:\Backup\VMs" -Exclude "test-vm-1","test-vm-2"
#>

[cmdletbinding()]
param (
    $Name,
    [Parameter(Mandatory=$true)]
    $ExportPath,
    $Exclude,
    $ZipExe     = "C:\Program Files\7-Zip\7z.exe",
    $Password,
    $ProcessCap = 2,
    $7zThreads  = 4,
    [switch]$FirstDiskOnly
)

if ($Name){
    $VMs = Get-VM | Where-Object {$Name -contains $_.Name -and $_.ReplicationMode -ne 'Replica'}
}else{
    $VMs = Get-VM | Where-Object {$Exclude -notcontains $_.Name -and $_.ReplicationMode -ne 'Replica'}
}
if ($VMs.Count -eq 0){
    Write-Warning "No VMs found"
    return
}

if ($Password){
    $EncryptArgs = "-p`"$Password`" -mhe"
}else{
    $EncryptArgs = $null
}

###Variables###
#check if 7zip is installed
if (Test-Path $ZipExe){
    $Zip = $true
    $StepCount=$VMs.count * 2
}else{
    $Zip = $false
    $StepCount=$VMs.count
}
$CurrentCount = 0
$7zProcess    = [System.Collections.ArrayList]@()
$PTitle       = "Backing up VM(s): $($VMs.count)"

#verify export path
if (!(Test-Path -Path $ExportPath)){
    Write-Error "Export path is unrechable. Please verify the path."
    return
}

:VMLoop foreach ($VM in $VMs) {
    $ExportFail   = $null
    $TempPath="$ExportPath\$($VM.Name).temp"
    Remove-Variable -Name MoveFail,ExtraDisks,VMOn -ErrorAction Ignore
    $Percent=[math]::Round($CurrentCount/$StepCount*100)

    if ($FirstDiskOnly){
        $ExtraDisks = $VM | Get-VMHardDiskDrive | Where-Object {!($_.ControllerLocation -eq 0 -and $_.ControllerNumber -eq 0)} | `
            Select-Object VMName,Name,ControllerNumber,ControllerLocation,ControllerType,DiskNumber,Path
    }

    Write-Progress -Activity $PTitle -Status "Exporting $($VM.Name)" -PercentComplete $Percent -Id 1
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
        write-verbose "Exporting VM: $($VM.Name)." -Verbose
        if ($FirstDiskOnly -and $ExtraDisks){
            #shutdown VM and remove extra disks
            Try {
                if ($VM.State -eq "Running") {
                    $VMOn = $true
                    Write-Verbose "Stopping VM: $($VM.Name)"
                    Stop-VM $VM -ErrorAction Stop
                }
            }catch{
                Write-Warning "Failed to stop VM $($VM.Name). Skipping"
                continue
            }
            foreach ($Disk in $ExtraDisks) {
                Write-Verbose "Removing extra disk: $($Disk.Name)"
                try{
                    Remove-VMHardDiskDrive -VMName $Disk.VMName -ControllerT $Disk.ControllerType -ControllerN $Disk.ControllerNumber -ControllerL $Disk.ControllerLocation -ErrorAction Stop
                }catch{
                    Write-Warning "Failed to remove disk $($Disk.Name) from VM $($VM.Name). Skipping export."
                    continue VMLoop
                }
            }
        }
        try{
            Export-VM -Name $VM.Name -Path $ExportPath -ErrorAction Stop
        }catch{
            Write-Warning "$($VM.Name) Export failed"
                if (Test-Path $TempPath){
                    if (Test-Path "$ExportPath\$($VM.Name)"){
                        Remove-Item -Path "$ExportPath\$($VM.Name)" -Force -Recurse -Confirm:$false
                    }
                Rename-Item -Path $TempPath -NewName "$ExportPath\$($VM.Name)"
            }
            $ExportFail = $true
        }
        if ($FirstDiskOnly -and $ExtraDisks){
            #Add disks if removed
            Write-Verbose "Adding extra disks back to VM: $($VM.Name)"
            foreach ($Disk in $ExtraDisks) {
                try{
                    Add-VMHardDiskDrive -VMName $Disk.VMName -Path $Disk.Path
                }catch{
                    Write-Warning "Failed to add disk $($Disk.Name) back to VM $($VM.Name)."
                    continue VMLoop
                }
            }
        }  

        if (!$ExportFail){
            Write-Verbose "Export successful"
            if (Test-Path $TempPath){
                Remove-Item -Path $TempPath -Force -Recurse -Confirm:$false 
            }
            
            if ($FirstDiskOnly -and $ExtraDisks){
                #start VM if stopped
                if ($VMOn) {
                    Write-Verbose "Starting VM: $($VM.Name)"
                    try{
                        Start-VM -Name $VM.Name -ErrorAction Stop
                    }catch{
                        Write-Warning "Failed to start VM $($VM.Name) after export."
                    }
                }
            }
            #run compression if 7zip is installed
            if ($Zip){
                Write-Verbose "Starting process to compress $($VM.Name)" -Verbose
                $FileName = "$($VM.Name)-$(Get-Date -Format "yy-MM-dd")"
                #child script
                $ChildScript = "while ((Get-Process 7z -ErrorAction SilentlyContinue).Count -ge $ProcessCap){Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 30)}; & '$ZipExe' a '$FileName' '$($VM.Name)' $EncryptArgs -mmt=$7zThreads -bsp1; if (Test-Path '$FileName.7z'){Remove-Item -Recurse -Force '$($VM.Name)'}"

                $7zProcess.Add((Start-Process powershell.exe -WorkingDirectory $ExportPath -ArgumentList "-NoProfile -Command `"$ChildScript`"" <#-WindowStyle Hidden#> -PassThru)) > $null
            }
        }
    }
    $CurrentCount++
}

if ($Zip){
    Write-Progress -Activity $PTitle -Status "Compressing VMs" -PercentComplete $Percent -Id 1
    #loop while waiting for 7zip processes to finish
    $TotalJobs = $7zProcess.Count
    Write-Verbose "Waiting for $TotalJobs 7zip processes to finish" -Verbose
    if ($TotalJobs -gt 0) {
        while ($true) {
            $7zProcess | ForEach-Object { $_.Refresh() }
            $RemainingJobs = $7zProcess | Where-Object { -not $_.HasExited }
            $RemainingCount = $RemainingJobs.Count
            $CompletedCount = $TotalJobs - $RemainingCount

            # Calculate overall completion percentage
            $Percent = [math]::Round(($CompletedCount / $TotalJobs) * 100)

            Write-Progress -Activity $PTitle `
                        -Status "Compressing VMs ($CompletedCount/$TotalJobs complete - $RemainingCount running)" `
                        -PercentComplete $Percent `
                        -Id 2

            #Exit loop when all background jobs have finished
            if ($RemainingCount -eq 0) { break }

            Start-Sleep -Seconds 2
        }

        Write-Progress -Activity $PTitle -Status "All compressions complete" -Completed -Id 2
    }
}else{
    Write-Output "7zip can be used to compress and archive VMs. Install 7zip or use custom install path in launch arguments."
}

Write-Progress -Activity $PTitle -Id 1 -Completed
