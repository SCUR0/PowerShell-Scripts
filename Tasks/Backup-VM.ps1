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

.EXAMPLE
  Backup-VM.ps1 -ExportPath "J:\Backup\VMs" -Exclude "test-vm-1","test-vm-2"
#>

[cmdletbinding()]
param (
    $Name,
    $ExportPath,
    $Exclude,
    $ZipExe="C:\Program Files\7-Zip\7z.exe",
    $Password 
)

if ($Name){
    $VMs = Get-VM | Where-Object {$Name -contains $_.Name}
}else{
    $VMs = Get-VM | Where-Object {$Exclude -notcontains $_.Name}
}
if ($VMs.Count -eq 0){
    Write-Warning "No VMs found"
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
$CurrentCount=0
$CompletedVMs = @()
$ExportFail = $null
$PTitle= "Backing up VM(s): ($($VMs.count))"


foreach ($VM in $VMs) {
    $TempPath="$ExportPath\$($VM.Name).temp"
    $MoveFail=$null
    $RemoveFail=$null
    $Percent=[math]::Round($CurrentCount/$StepCount*100)
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
        write-verbose "Exporting VM: $($VM.Name)."
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
        if (!$ExportFail){
            Write-Verbose "Export successful"
            if (Test-Path $TempPath){
                Remove-Item -Path $TempPath -Force -Recurse -Confirm:$false 
            }
            $CompletedVMs += $VM.Name
        }
    }
    $CurrentCount++
}

Write-Progress -Activity "Backing up VM(s) ($($VMs.count))" -Completed

#Compress if 7zip is installed
if ($Zip -and ($CompletedVMs)){
    Write-Verbose "Compressing Exports"
    cd $ExportPath

    foreach ($CompletedVM in $CompletedVMs){
        Write-Verbose "Compressing $CompletedVM"
        $Percent=[math]::Round($CurrentCount/$StepCount*100)
        Write-Progress -Activity $PTitle -Status "Compressing $CompletedVM" -PercentComplete $Percent -Id 1
        $FileName = "$CompletedVM-$(Get-Date -Format "yy-MM-dd")"
        Start-Process -FilePath $ZipExe -ArgumentList "a $FileName $CompletedVM $EncryptArgs -bsp1" -NoNewWindow -PassThru | ForEach-Object {
            if ($_ -match '\S'){
                $String = ($_ | Out-String).Trim()
                $CompPerc = ($String -split '%')[0]
                if ($CompPerc -match '^[0-9]+$'){
                    Write-Progress -Activity "Compressing" -Status "$CompPerc% Completed" -PercentComplete $CompPerc -Id 2
                }
            }
        }
        Write-Progress -Activity "Compressing" -Id 2 -Completed
        if (Test-Path "$FileName.7z"){
            Write-Verbose "Deleting uncompressed files"
            remove-item -Recurse -Force $CompletedVM
        }
        $CurrentCount++
    }
}else{
    if (!$Zip){
        Write-Output "7zip can be used to compress and archive VMs. Install 7zip or use custom install path in launch arguments."
    }
}

Write-Progress -Activity $PTitle -Id 1 -Completed
