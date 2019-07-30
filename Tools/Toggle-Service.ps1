<#
.SYNOPSIS
  Toggle Services

.DESCRIPTION
  This script is used for quick toggle of services.

.PARAMETER Service
  Name of Service to toggle.

.PARAMETER ComputerName
  Opptional parameter for remote computer.

#>
[cmdletbinding()]
param (
    [string]$ComputerName,
    [Parameter(Mandatory=$True)]
    [string]$Service
)

If ($ComputerName){
    $Switch = "-ComputerName $ComputerName"
}else{
    $Switch = $null
}

Invoke-Expression -Command "Invoke-Command $Switch -ScriptBlock{
    `$ServiceObj = Get-Service $Service
    If (`$ServiceObj.Status -eq `"Running`"){
        Write-Verbose `"Stopping $Service`" -Verbose
        Stop-Service `$ServiceObj
    }Else{
        Write-Verbose `"Starting $Service`" -Verbose
        Start-Service `$ServiceObj
    }
}" 