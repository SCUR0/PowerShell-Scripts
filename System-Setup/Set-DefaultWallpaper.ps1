function RefreshWallpaper ($wallpaper){
    Add-Type @”
        using System;
        using System.Runtime.InteropServices;
        using Microsoft.Win32;

        namespace Wallpaper{
            public class UpdateImage{
                [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
                private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
                public static void Refresh(string path) {
                    SystemParametersInfo( 20, 0, path, 0x01 | 0x02 ); 
                }
            }
        }
“@
    Write-Debug 'The wallpaper being refreshed is: $wallpaper'
    [Wallpaper.UpdateImage]::Refresh($wallpaper)
    Write-Debug 'Post Wallpaper refresh TranscodeImagecache value: $(ConvertFrom-Hexa)'
}

#Set permissions
takeown /f $env:windir\Web\Wallpaper\Windows\img0.jpg /a
takeown /f $env:windir\Web\4K\Wallpaper\Windows\*.* /a
icacls $env:windir\Web\Wallpaper\Windows\img0.jpg /Grant 'Administrators:(F)'
icacls $env:windir\Web\4K\Wallpaper\Windows\*.* /Grant 'Administrators:(F)'
 
#Rename default wallpaper
Rename-Item $env:windir\Web\Wallpaper\Windows\img0.jpg img1.jpg -Force -ErrorAction SilentlyContinue
 
#Copy new default wallpaper
Copy-Item $PSScriptRoot\images\img0.jpg $env:windir\Web\Wallpaper\Windows -Force
#Copy alternative resolutions
Copy-Item $PSScriptRoot\images\4K\*.* $env:windir\Web\4K\Wallpaper\Windows -Force

RefreshWallpaper "$env:windir\Web\Wallpaper\Windows\img0.jpg"