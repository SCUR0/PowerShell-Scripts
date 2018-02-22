<#
.SYNOPSIS
  Sets NTFS compression to directories.

.DESCRIPTION
  Scans folders saved in variable recursively to check for files not compressed.
  Any files found not compressed, NTFS basic compression will apply.
#>

#Folder directories to be checked for compression
#The ones below are examples.

$compressfolders=(
  "D:\Backup",
  "D:\Shared\Video Projects",
  "D:\Shared\Software"
)


foreach ($folder in $compressfolders) {
    Get-ChildItem $folder -Recurse| where-object {$_.Attributes -notlike "*Compressed*"} | 
    ForEach-Object {
        compact /C $_.FullName
    }
}
