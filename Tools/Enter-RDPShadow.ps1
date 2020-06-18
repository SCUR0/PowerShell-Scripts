<#
.SYNOPSIS
    RDP shadow and control remote computers

.DESCRIPTION
	Allows remote viewing of users sessions using built in methods. A console session is automatically found if it exists.

.PARAMETER Computer
	IP or name of remote computer to shadow.

.PARAMETER Silent
	RDP Shadow with no notification given to the user.
#>
[CmdletBinding()]
Param(
	[Parameter(mandatory=$true)]
	[string]$ComputerName,
	[switch]$Silent
)

#Load message box
Add-Type -AssemblyName PresentationFramework

if (Test-Connection $ComputerName -Count 2 -Quiet){
    $Sessions = qwinsta /server:$ComputerName 2>$null |
        #Parse output
        ForEach-Object {
            $_.Trim() -replace "\s+",","
        } |
        #Convert to objects
        ConvertFrom-Csv
    $Console = $Sessions | Where-Object {$_.SESSIONNAME -eq "console"}
    If (($Console) -and ($Console.ID -match '^[0-9]+$')){
        if(!($Silent)){
            
            $DisplayName = $env:Username

            #Send notify message of connection
            $MessageTitle = "Remote Access From OHSD IS Dept"
            $MessageString = "$DisplayName is connecting to your computer."
            Try{
                Send-RDUserMessage -HostServer $ComputerName -UnifiedSessionID $($Console.ID) `
                    -MessageTitle $MessageTitle `
                    -MessageBody $MessageString  -ErrorAction Stop
            }Catch{
                Write-Warning "Required AD module not installed. Installing"
                Get-WindowsCapability -Name Rsat.ActiveDirectory* -Online | Add-WindowsCapability -Online | Out-Null
                Send-RDUserMessage -HostServer $ComputerName -UnifiedSessionID $($Console.ID) `
                    -MessageTitle $MessageTitle `
                    -MessageBody $MessageString 
            }
        }
        Start-Process Mstsc -ArgumentList "/shadow:$($Console.ID)", "/v:$ComputerName", "/control", "/noconsentprompt" -wait
        Send-RDUserMessage -HostServer $ComputerName -UnifiedSessionID $($Console.ID) `
            -MessageTitle $MessageTitle `
            -MessageBody "$DisplayName has disconnected from your computer."
    }else{
        $ErrorMessage = "No console session was found on $ComputerName. `nVerify you are logged as admin and a user is logged in."
        Write-Error $ErrorMessage
        [System.Windows.MessageBox]::Show($ErrorMessage,'No User Found','Ok','Error') | Out-Null
    }
}else{
    $ErrorMessage = "Unable to reach $ComputerName. Verify the computer is online."
	Write-Error $ErrorMessage
    [System.Windows.MessageBox]::Show($ErrorMessage,'Computer Unreachable','Ok','Error') | Out-Null
}