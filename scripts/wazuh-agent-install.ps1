# ============================================================
# KingSecure Homelab - Wazuh Agent Installation Script
# Domain: kingsecure.bj
# Wazuh Manager: 10.10.10.50
# ============================================================

param(
    [string]$WazuhManager = "10.10.10.50",
    [string]$WazuhVersion = "4.7.0"
)

$WazuhInstallerUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WazuhVersion-1.msi"
$InstallerPath = "$env:TEMP\wazuh-agent.msi"

Write-Host "=== KingSecure Wazuh Agent Installer ===" -ForegroundColor Cyan
Write-Host "Manager IP: $WazuhManager" -ForegroundColor Yellow

# Download Wazuh agent
Write-Host "Downloading Wazuh agent..." -ForegroundColor Yellow
Invoke-WebRequest -Uri $WazuhInstallerUrl -OutFile $InstallerPath

# Install Wazuh agent
Write-Host "Installing Wazuh agent..." -ForegroundColor Yellow
msiexec /i $InstallerPath /q WAZUH_MANAGER=$WazuhManager WAZUH_REGISTRATION_SERVER=$WazuhManager

# Start Wazuh service
Write-Host "Starting Wazuh service..." -ForegroundColor Yellow
Start-Service -Name "WazuhSvc"
Set-Service -Name "WazuhSvc" -StartupType Automatic

# Verify installation
$Service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
if ($Service.Status -eq "Running") {
    Write-Host "Wazuh agent installed and running successfully!" -ForegroundColor Green
} else {
    Write-Host "Wazuh agent installation may have failed. Check logs." -ForegroundColor Red
}

# Cleanup
Remove-Item $InstallerPath -Force
Write-Host "Installation complete." -ForegroundColor Green
