<#
.SYNOPSIS
  Sets NTFS compression to directories.

.PARAMETER  Path
	Path to location that compression needs to be checked. Supports multiple paths.

.PARAMETER  State
	State of file compression you want set.

.DESCRIPTION
  Scans folders recursively to check for ntfs compression.
  Any files found not in the requested compression state will be changed.
#>

[CmdletBinding()]
param (
	$Path,
	[ValidateSet('compress','uncompress')]
	[string]$State = 'compress'
)
if ($State -eq 'uncompress'){
	$CMDState = '/U'
}else{
	$CMDState = '/C'
}

foreach ($folder in $Path) {
    $Parent = Get-ChildItem $folder -Recurse
    if ($CMDState -eq 'compress'){
        $Children = $Parent | where-object {$_.Attributes -notlike "*Compressed*"}
    }else{
        $Children = $Parent | where-object {$_.Attributes -like "*Compressed*"}
    }

    foreach ($Child in $Children){
        compact $CMDState $Child.FullName
    }
}