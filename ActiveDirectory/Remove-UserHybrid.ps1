<#
.SYNOPSIS
Closes user accounts. 

.DESCRIPTION
Closes accounts with best practice procedures which involve archiving files and
setting rules to forward emails.

.PARAMETER username
Used as the identifier for which account will be closed.

.EXAMPLE
remove-user.ps1 jsmith 

This will close jsmith's account.
#>

[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)]
    [string] $username,
    [Parameter(Mandatory=$false)]
    [switch] $keepfiles
    
)

function Test-Administrator{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

if (!(Test-Administrator)){
    Write-Error "Please launch script with administrative rights."
    pause
    exit
}


#config
$RUOConfig =@{
    #default variables
    Org = "Organization"
    Email = "domain.org"
    OnsiteExchange="exchange-01"

    ShareEmail = "\\domain.org\dfs\AdminScripts\Exchange\Share-OnlineEmailAccount.ps1"
    ArchiveUserFiles = "\\domain.org\dfs\AdminScripts\ad\Archive-UserFiles.ps1"
    RecyclebinOU = "OU=RecycleBin,DC=esd189,DC=org"
    
    #Email from address
    FromEmail = "techservices@domain.org"
    #index 0 is $ticket
    ToEmail = "tckt-update-{0}@helpdesk.domain.org"
    SmtpServer = "mailhub.domain.org"
}

#Varibles
$date = Get-Date
if (!$cred){
    Write-Output "Input credentials for Exchange Online:"
    $cred = Get-Credential "$env:Username@$($RUOConfig.email)"
}
#exchang online
if (!(get-pssession -name "EOSession" -ErrorAction SilentlyContinue)){
    try{
        $EOSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" `
            -Credential $cred -Authentication "Basic" -AllowRedirection -Name "EOSession" -ErrorAction Stop
    }catch{
        Write-Error $error[0]
        pause
        exit
    }
    Import-PSSession $EOSession -DisableNameChecking | out-null
}
#Connect to local exchange server used for creation
if (!(get-pssession -name "ExSession" -ErrorAction SilentlyContinue)){
    Write-Verbose "Connecting to local Exchange Server" -Verbose
    $ExSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$($RUOConfig.OnsiteExchange)/powershell -Name "ExSession"
    Import-PSSession $ExSession -Prefix local -DisableNameChecking | out-null
}

do {
    if ($userverif -eq "n"){
        $username = Read-Host "Username to disable"
    }

#Verify username
    do{
        $Usercheck = Get-ADUser -LDAPFilter "(sAMAccountName=$username)" -ErrorAction SilentlyContinue
        if ($null -eq $Usercheck){
            Write-Warning "Username not found."
            $username = Read-Host "Username does not exist. Please provide correct username."
            $usergood = $false
        }else{
            $usergood = $true
        }
    } until ($usergood -eq $true)

	#verification of user
    get-aduser $username | Write-Output
    $userverif = read-host "Is this the correct user? [Y] or [N]"
} until ($userverif -eq "y")


#continue Variables
$forwardTo = Read-Host "Username of staff member to forward inquiries to hit enter to skip."
#This part pulls the full name based off the admin account names used in ESD.
$parts = $env:username.split("-")
$RunningUsername = $parts[1]
try{
    $RunningUser = get-aduser $RunningUsername
}
catch{
    $RunningUser.Name = $env:username
}

#forward username check
if ($forwardTo){
    do{
        $Usercheck = Get-ADUser -LDAPFilter "(sAMAccountName=$forwardTo)" -ErrorAction SilentlyContinue        
        if ($null -eq $Usercheck){
            Write-Warning "Username does not exist."
            $forwardTO = Read-Host "Forwarding username does not exist. Please provide correct username."
            $usergood = $false
        }else{
            $usergood = $true
        }
    } until ($usergood -eq $true)
}

#last of Variables
$ADuser = Get-ADuser $username -Properties memberOf
$groups = $ADuser.memberOf |ForEach-Object {Get-ADGroup $_}

### Main script

#Remove groups
$GroupsString = $groups.name | Format-list | Out-String 
$groups |ForEach-Object {Remove-ADGroupMember -Identity $_ -Members $username -Confirm:$false}
write-verbose "$username removed from groups: `n$GroupsString" -Verbose

#check for managed folders and run script
$mailbox = Get-MailboxFolderStatistics $username | Where-Object {$_.Name -eq "Managed Folders"}

if ($($mailbox.ItemsInFolderAndSubfolders) -gt 0){
    Write-Warning "Email found in managed folders!"
    $runmfscript= read-host "Would you like to give replacement access to managed folders? [y] or [n]"
    if ($runmfscript -eq "y"){
        $ExportTo = read-host "Username to share to"
        & "$($RUOConfig.ShareEmail)" $username $ExportTo -verbose
    }
}else{
    Write-Verbose "No emails found in managed folder." -Verbose
    #hide mailbox
    Write-Verbose "Hiding address from address list." -Verbose
    Set-localRemotemailbox -Identity $username -HiddenFromAddressListsEnabled $true -ErrorAction SilentlyContinue
}

#Set auto reply
if ($forwardTo){
    Set-MailboxAutoReplyConfiguration $username -AutoReplyState enabled -ExternalAudience all -InternalMessage `
    "$($ADuser.name) is no longer working for $($RUOConfig.Organization). Please email inquiries to ${forwardTo}@$($RUOConfig.Email). Thank you." `
    -ExternalMessage "$($ADuser.name) is no longer working for $($RUOConfig.Organization). Please email inquiries to `
    ${forwardTo}@$($RUOConfig.Email). Thank you."
    write-verbose "Auto reply set to forward to ${forwardTo}@$($RUOConfig.Email)" -Verbose
}

#set up redirect email rule
if($forwardTo){
    new-inboxrule -name "Redirect Email To Replacement" -mailbox "$username"  -MyNameinToBox $true -RedirectTo "${forwardto}@$($RUOConfig.Email)" `
    -ErrorAction SilentlyContinue -Confirm:$false -force | Out-Null
    write-verbose "Redirecting emails to ${forwardTo}@$($RUOConfig.Email)" -Verbose
}

#non forward action
if(!$forwardTo){
    Set-MailboxAutoReplyConfiguration $username -AutoReplyState enabled -ExternalAudience all -InternalMessage `
    "We are sorry but $($ADuser.name) is no longer working for $($RUOConfig.Org)." `
    -ExternalMessage "We are sorry but $($ADuser.name) is no longer working for $($RUOConfig.Org)."
    write-verbose "Auto reply set." -Verbose
}
write-verbose "Mailbox closure steps complete." -Verbose

#prompt before disable of account
write-warning "Please check to see if google docs is empty for ${username}. do NOT continue the script untill you have checked."
pause

#Creates description for disabled
$terminatedby = $env:username
$termDate = get-date -uformat "%Y.%m.%d"
$termUserDesc = "Disabled " + $termDate + " - " + $terminatedby
set-ADUser $username -Description $termUserDesc 
write-verbose "$username description set to $termUserDesc" -verbose

#disable and move
$RecyclebinOUPath = "OU=Deleted in $($date.year)," + $($RUOConfig.RecyclebinOU)
Disable-ADAccount -Identity $username
Try {
	Move-ADObject -Identity $ADuser -TargetPath $RecyclebinOUPath
} catch {
    New-ADOrganizationalUnit -Name ("Deleted in $($date.year)") -Path "$($RUOConfig.RecyclebinOU)"
    Move-ADObject -Identity $ADuser -TargetPath $RecyclebinOUPath
}
Start-Sleep -Seconds 6

#Call Archive user script
if (!$keepfiles){
    . "$($RUOConfig.ArchiveUserFiles)" $username -verbose
}

#update ticket
Write-verbose "if Would you like this script to update the ticket please input the ticket [number]." -Verbose
$ticket = Read-Host  "Otherwise press [enter] and the script will finish."

#updates ticket
if ($ticket -gt 20000){
    $ToEmail = $RUOConfig.ToEmail -f $ticket
    $ticketmessageParameters = 
    @{  
        From = "$($RUOConfig.FromEmail)"    
        To = $ToEmail
        SmtpServer = $($RUOConfig.SmtpServer)
        Subject = "Ticket Updated: [$ticket] Remove Account"
        Body = "Account has been disabled and archived.
        The account was removed from the following groups:
        
        $GroupsString
        
        Script for removal was run by $($RunningUser.Name)."
    }
    Send-MailMessage @ticketmessageParameters
    Write-verbose "Ticket has been updated and the script is compete." -Verbose
    Start-Sleep -Seconds 5
}else{
    Write-Verbose "The ticket was not updated and the script is now complete" -Verbose
    Start-Sleep -Seconds 2
}
