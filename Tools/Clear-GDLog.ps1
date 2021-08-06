[cmdletbinding()]
param (
    [string]$ComputerName
)

$Script = {
    #log path
    $LogDir = "C:\Windows\System32\config\systemprofile\AppData\Local\Google\DriveFS\Logs\"

    #check if google drive is running
    $GDrive = get-process | where {$_.name -eq "GoogleDriveFS"}

    if ($GDrive){
        Write-Output "Closing Google Drive"
        $GDrive | Stop-Process -Force
        while (get-process | where {$_.name -eq "GoogleDriveFS"}){
            Start-Sleep -s 1
        }
    }
    
    if (Test-Path $LogDir){
        $LargeCount = 0
        $Files = Get-ChildItem -Path $LogDir
        foreach ($File in $Files){
            $FileSize = ([System.IO.FileInfo] $File).length / 1mb
            if ($FileSize -gt 5){
                Write-Output "Removing large debug log: $($File.Name)"
                $File | Remove-Item  -Force
                $LargeCount++
            }    
        }
        if ($LargeCount -eq 0){
            Write-Output "No abnormal log sizes found"
        }        
    }
}


if ($ComputerName){
    if (Test-Connection $ComputerName -Quiet -Count 2){
        try {
            Invoke-Command -ComputerName $ComputerName -ScriptBlock $Script -ErrorAction Stop
        }catch{
            Write-Warning "Remote session failed. Attempting to clear temp files to make room and try again with psexec"
            
            #try to clear some files to make room and try psexec
            $TempFolders = @(
                "\\$ComputerName\C$\Intel\",
                "\\$ComputerName\C$\Windows\Temp\*",
                "\\$ComputerName\C$\Windows\Prefetch\*",
                "\\$ComputerName\C$\Documents and Settings\*\Local Settings\temp\*",
                "\\$ComputerName\C$\Users\*\Appdata\Local\Temp\*"
            )
            Remove-Item $TempFolders -Force -Recurse -ErrorAction SilentlyContinue
            \\ohsd.net\dfs\AdminScripts\Tools\psexec\PsExec64.exe -accepteula -s \\$ComputerName powershell -file "$PSCommandPath"
        }
    }else{
        Write-Warning "Unable to reach $ComputerName"
    }
}else{
    .$Script
}
