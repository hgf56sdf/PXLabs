# PowerShell script to download and set wallpaper
# Requires elevation for writing to System32 directory

# Define variables
$wallpaperURL = "https://pxlabs.netlify.app/uploads/minimalist.png"
$wallpaperDest = "$env:USERPROFILE\Pictures\PXLabs_wallpaper.png"

# Create Pictures directory if it doesn't exist (shouldn't be needed but just in case)
$picturesDir = Split-Path $wallpaperDest -Parent
if (!(Test-Path $picturesDir)) {
    New-Item -Path $picturesDir -ItemType Directory -Force | Out-Null
    Write-Output "Created directory: $picturesDir"
}

# Download the wallpaper
Write-Output "Downloading wallpaper from: $wallpaperURL"
Write-Output "Saving to: $wallpaperDest"

try {
    # Use TLS 1.2 for better compatibility
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Download with better error handling
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "PowerShell Wallpaper Script")
    $webClient.DownloadFile($wallpaperURL, $wallpaperDest)
    $webClient.Dispose()
    
    Write-Output "Wallpaper downloaded successfully."
} catch {
    Write-Error "Failed to download wallpaper: $($_.Exception.Message)"
    exit 1
}

# Verify the file was downloaded and is a valid image
if (!(Test-Path $wallpaperDest)) {
    Write-Error "Wallpaper file was not created at $wallpaperDest"
    exit 1
}

$fileSize = (Get-Item $wallpaperDest).Length
if ($fileSize -lt 1024) {
    Write-Error "Downloaded file is too small ($fileSize bytes) - likely not a valid image"
    exit 1
}

Write-Output "File downloaded successfully. Size: $([math]::Round($fileSize/1KB, 2)) KB"

# Set wallpaper using multiple methods for better compatibility
Write-Output "Setting wallpaper..."

try {
    # Method 1: Registry approach
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaperDest -ErrorAction Stop
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "6" -ErrorAction Stop  # Fit
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0" -ErrorAction Stop
    
    # Method 2: SystemParametersInfo API call
    Add-Type -TypeDefinition @"
        using System;
        using System.Runtime.InteropServices;
        public class Wallpaper {
            [DllImport("user32.dll", CharSet = CharSet.Auto)]
            public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
        }
"@ -ErrorAction SilentlyContinue

    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02
    
    $result = [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperDest, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)
    
    if ($result -eq 0) {
        Write-Warning "SystemParametersInfo returned 0 - wallpaper may not have been set properly"
    }
    
    # Method 3: Fallback using rundll32
    Start-Process "rundll32.exe" -ArgumentList "user32.dll,UpdatePerUserSystemParameters" -Wait -WindowStyle Hidden
    
    Write-Output "Wallpaper applied successfully!"
    Write-Output "If the wallpaper doesn't appear immediately, try refreshing the desktop (F5) or logging out and back in."
    
} catch {
    Write-Error "Failed to set wallpaper: $($_.Exception.Message)"
    
    # Provide manual instructions as fallback
    Write-Output ""
    Write-Output "Manual setup instructions:"
    Write-Output "1. Right-click on desktop and select 'Personalize'"
    Write-Output "2. Go to Background settings"
    Write-Output "3. Browse and select: $wallpaperDest"
    
    exit 1
}

Write-Output "Script completed successfully!"