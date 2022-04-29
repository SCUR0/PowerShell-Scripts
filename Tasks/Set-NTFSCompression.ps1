<#
.SYNOPSIS
    Sets NTFS compression to directories.

.PARAMETER  Path
    Path to location that compression needs to be checked. Supports arrays.

.PARAMETER  Exclude
    File extensions to exclude from compression. Common compressed files set as default.

.PARAMETER  State
    State of file compression you want set.

.PARAMETER  Progress
    Show progress bar. Recommended to not be shown if running as a task due to overhead. Use -Progress:$false to hide.

.DESCRIPTION
    Scans folders recursively to check for ntfs compression.
    Any files found not in the requested compression state will be changed.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    $Path,
    $Exclude = ('*.7z', '*.zip','*.mp4','*.mp3','*.mov','*.mkv'), 
    [ValidateSet('compress','uncompress')]
    [string]$State = 'compress',
    [switch]$Progress = $true
)

if ($State -eq 'compress'){
    $StateString = 'Compressing'
}else{
    $StateString = 'Uncompressing'
}

foreach ($Folder in $Path) {
    Write-Verbose "Analysing $Folder" -Verbose
    $Parent = Get-ChildItem $Folder -Recurse -Exclude $Exclude

    if ($Progress){
        $Total = $Parent.Count
        $i = 1
        #Adjust update interval based on total amount
        if ($Total -le 1000){
            $Division = 1
        }elseif ($Total -ge 10000){
            $Division = 100
        }else{
            $Division = 10
        }
    }
    

    foreach ($Child in $Parent){
        if ($Progress -and ($i % $Division -eq 0)){
            Write-Progress -Activity "$StateString Data" -Status "$i/$Total $($Child.Directory.FullName)"  -PercentComplete ($i / $Total * 100)
        }
        $i++
        if ($State -eq 'compress' -and $Child.Attributes -notlike '*Compressed*'){
            compact /C $Child.FullName /q > $null
        }elseif($State -eq 'uncompress' -and $Child.Attributes -like '*Compressed*'){
            compact /U $Child.FullName /q > $null
        }
    }
    if ($Progress){
        Write-Progress -Activity "$StateString Data" -Completed
    }
}