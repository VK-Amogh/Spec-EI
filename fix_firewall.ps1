# SpecEI Firewall Fix Script
# Run this as Administrator

Write-Host "Configuring Windows Firewall for SpecEI..." -ForegroundColor Cyan

# 1. Gateway Port (8080)
New-NetFirewallRule -DisplayName "SpecEI Gateway" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
Write-Host "✅ Port 8080 (Gateway) - OPENED" -ForegroundColor Green

# 2. Whisper Port (8000)
New-NetFirewallRule -DisplayName "SpecEI Whisper" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
Write-Host "✅ Port 8000 (Whisper) - OPENED" -ForegroundColor Green

# 3. Mistral Port (8001)
New-NetFirewallRule -DisplayName "SpecEI Mistral" -Direction Inbound -LocalPort 8001 -Protocol TCP -Action Allow
Write-Host "✅ Port 8001 (Mistral) - OPENED" -ForegroundColor Green

Write-Host "------------------------------------------------"
Write-Host "Firewall configuration complete!" -ForegroundColor Cyan
Write-Host "Ensure your phone is connected to the same Wi-Fi network." -ForegroundColor Yellow
Start-Sleep -Seconds 5
