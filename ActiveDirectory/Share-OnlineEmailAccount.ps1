<#
.SYNOPSIS
Shares Managed Folders.

.DESCRIPTION
Shares folders with another user. Primarily used for when the original user leaves.

.PARAMETER FromEmail
Used as the identifier for which account will share their folder.

.PARAMETER ToEmail
Used as the identifier for which account will now have access to managed folder.

.PARAMETER Credential
Credentials used to access office 365 exchange.

.EXAMPLE
Share-OnlineEmailAccount.ps1 jsmith jdoe

This will share all of John Smith's email to jdoe.
#>

[cmdletbinding()]
param (
    [Parameter(Mandatory=$true)]
    [string] $FromEmail,
    [Parameter(Mandatory=$true)]
    [string] $ToEmail,
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credential
)

#config hash
$SMFConfig =@{
    Organization = "Organization"
    domain = "domain.org"

    #email sent to new user
    SendFromEmail = "techservices@domain.org"
    SmtpServer = "mailhub.domain.org"
}

#adds domain if not included
if ($ToEmail -notlike "*@$($SMFConfig.domain)"){
    $ToEmail = $ToEmail + "@$($SMFConfig.domain)"
}

if ($FromEmail -notlike "*@$($SMFConfig.domain)"){
    $FromEmail = $FromEmail + "@$($SMFConfig.domain)"
}


#connect to exchange online
if (!(get-pssession -name "EOSession")){
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


Write-Verbose "Applying share permission to $FromEmail."
Add-MailboxPermission -Identity $FromEmail -User $ToEmail -AccessRights FullAccess -Automapping:$true | Out-Null


#sends email
$managedfoldermessageParameters = 
@{  
    From = $SMFConfig.SendFromEmail                        
    To = $ToEmail
    SmtpServer = $SMFConfig.SmtpServer                      
    Subject = "Managed Folder Transfer"                       
    Body = "Hello,
The email account of $FromEmail has been shared to your email account. To access this shared account you will soon see a new email account ($FromEmail) appear
in the bottom left of your outlook. Please copy the emails you would like to keep in the Managed Folder to your own Managed Folder.
    
When you are done with copying emails please contact the help desk and we can remove the shared account for you.

Thank you.
        
 -Technology Services"
}

Send-MailMessage @managedfoldermessageParameters
Write-Verbose "Notification email sent to $ToEmail."

