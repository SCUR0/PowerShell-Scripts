<#
.SYNOPSIS
  Uncompresses files recusivly

.DESCRIPTION
  This script can be used to recusivly uncompress files.
  This script will skip already uncompressed files.

.PARAMETER CompressedFolders
  Can be a single or multiple forlders
#>
[cmdletbinding()]
param (
    [Parameter(Mandatory=$True)]
    [string]$CompressedFolders
)

foreach ($Folder in $CompressedFolders) {
    Get-ChildItem $Folder -Recurse| where-object {$_.Attributes -like "*Compressed*"} | 
    ForEach-Object {
        compact /U $_.FullName
    }
}