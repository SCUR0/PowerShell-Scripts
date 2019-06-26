<#
.SYNOPSIS
  Pull CPU stats

.DESCRIPTION
  Retreives CPU performance information via powershell.
  Useful for checking remote computers.

.PARAMETER ComputerName
  Name or IP of computer to pull stats from.
  Defaults to localhost.

.PARAMETER Processes
  Amount of top proccesses shown.
  Defaults to 5.

#>

[cmdletbinding()]
param (
    $ComputerName = "localhost",
    $Processes = 5
)

$Script = {
    #Two extra entries are added for calculating load
    $Processes = $args[0] + 3
    $Output = @()
    $CPUStats = Get-Counter '\Process(*)\% Processor Time' -ErrorAction SilentlyContinue | `
        Select-Object -ExpandProperty countersamples | `
        Select-Object -Property instancename, cookedvalue| `
        Sort-Object -Property cookedvalue -Descending| `
        Select-Object -First $Processes

    $Output += New-Object PSCustomObject -Property `
        @{Program = "Total"; Percent = [math]::ROUND(1 - ($CPUStats[1].CookedValue / $CPUStats[0].CookedValue),4).tostring("P")}

    For ($i = 2; $i -lt ($CPUStats.Length - 1); $i++){
        $Output += New-Object PSCustomObject -Property `
            @{Program = $CPUStats[$i].InstanceName; Percent = [math]::ROUND(($CPUStats[$i].CookedValue / $CPUStats[0].CookedValue),4).tostring("P")}
    }
    Write-Output $Output | Select-Object Program,Percent

}

if ($ComputerName -eq "localhost"){
    Invoke-command -ArgumentList $Processes -ScriptBlock $Script
}else{
    Invoke-command -ComputerName $ComputerName -ArgumentList $Processes -ScriptBlock $Script
}
