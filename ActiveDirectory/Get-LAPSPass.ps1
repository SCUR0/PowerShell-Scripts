<#
.SYNOPSIS
    GUI LAPS Retrieval

.DESCRIPTION
	GUI script that does not require any modules installed to pull LAPS password

.PARAMETER ComputerName
	Hostname of computer to search for password
#>
Param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName
)

#Load message box
Add-Type -AssemblyName PresentationFramework

#Find ldap object
$Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
$Searcher.Filter = "(&(objectCategory=computer)(cn=$ComputerName))"
$LDAPObject = $Searcher.FindOne()
#perform lookup
if ($LDAPObject){
    if ($LDAPObject.Properties.PropertyNames -like 'ms-mcs-admpwd'){
        $LAPsPass = $LDAPObject.Properties.'ms-mcs-admpwd'
        if ($LAPsPass){
            Write-Output "LAPS Password: $LAPsPass"
            $Button = [System.Windows.MessageBox]::Show("Password: $LAPsPass`n`nClick OK to copy",'LAPS Password',"OKCancel","Information")
            if ($Button -eq "OK"){
                Set-Clipboard -Value $LAPsPass
            }
        }else{
            $ErrorMessage = "No password was found for $ComputerName"
            Write-Warning $ErrorMessage
            [System.Windows.MessageBox]::Show($ErrorMessage,'No Password','Ok','Exclamation') | Out-Null
        }
    }else{
        $ErrorMessage = "This account appears to not have access to LAPS passwords. Verify that account is part of GRP_LAPSReaders and relog if it was recently added."
        Write-Warning $ErrorMessage
        [System.Windows.MessageBox]::Show($ErrorMessage,'LAPS Access Denied','Ok','Exclamation') | Out-Null
    }
}else{
    $ErrorMessage = "No computer object was found in active directory for $ComputerName"
	Write-Error $ErrorMessage
    [System.Windows.MessageBox]::Show($ErrorMessage,'Computer Not Found','Ok','Error') | Out-Null
}
