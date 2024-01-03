[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$PrintServer
)

#determine if part of admin group
if (([Security.Principal.WindowsIdentity]::GetCurrent().Groups | Select-String 'S-1-5-32-544')){
    #checks if running elevated
    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
        $Admin = $true
    }else{
        $Admin = $false
    }
}else{
    $Admin = $false
}


#parse net view to get names of printers on print server
Write-Verbose "Pulling list of printers from $PrintServer" -Verbose
$NetView = net view $PrintServer
$NetView[0] = $null
$NetView[-1] = $null
$SrvPrinters = $NetView -match '\w' | foreach { 
    ConvertFrom-String $_.trim() -delim '\s{2,}' -PropertyNames 'Share','Type' | Select-Object 'Share','Type'
}

if ($NetView){
    if ($Admin){
        #pull printers from registry
        $RegistryPrinters = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Connections"
        $LocalPrinters = [System.Collections.ArrayList]@()
        foreach ($Printer in $RegistryPrinters){
            $LocalPrinter = New-Object -TypeName psobject
            $LocalPrinter | Add-Member -MemberType NoteProperty -Name RegKey -Value $Printer.PSPath
            $LocalPrinter | Add-Member -MemberType NoteProperty -Name PrinterName -Value $Printer.GetValue("Printer").Split("\")[3]
            $LocalPrinter | Add-Member -MemberType NoteProperty -Name PrinterPath -Value $Printer.GetValue("Printer")
            $LocalPrinter | Add-Member -MemberType NoteProperty -Name PrinterServer -Value $Printer.GetValue("Server")
            $LocalPrinters.Add($LocalPrinter) > $null
        }

        #cross reference with print server list
        $OrphPrinters = [System.Collections.ArrayList]@()
        foreach ($Printer in $LocalPrinters){
            if ($SrvPrinters.Share -notcontains $Printer.PrinterName){
                Write-Verbose "$($Printer.PrinterName) not found" -Verbose
                $OrphPrinters.add($Printer) > $null
            }
        }
        #remove system printers
        if ($OrphPrinters){
            Write-Verbose 'Attempting to remove orphaned group policy printers' -Verbose
            Stop-Service spooler
            foreach ($Printer in $OrphPrinters){
                Remove-Item $Printer.RegKey -Confirm:$false -Verbose
            }
            Start-Service spooler
        }
    }

    #check user printers
    $UserPrinters = Get-Printer | Where-Object {$_.Type -eq 'Connection'}
    foreach ($Printer in $UserPrinters){
        #remove printer if the name is from a print server and
        if (($Printer.Name -like "\\$PrintServer*") -and ($SrvPrinters.Share -notcontains $Printer.ShareName)){
             Write-Verbose "$($Printer.Name) not found on print server. Removing" -Verbose
             $Printer | Remove-Printer
        }
    }
}
