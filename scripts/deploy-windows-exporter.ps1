
# STACKWATCH: Windows Exporter Deployment Script (PowerShell)
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - PowerShell script ONLY (NO Ansible, NO WinRM automation)
# - Does NOT modify frontend
# - Backward compatible
# - Must be run on Windows server with Administrator privileges

param(
    [string]$NodeExporterPort = "9100",
    [string]$WindowsExporterVersion = "0.31.3",
    [switch]$SkipFirewall = $false
)

# Error handling
$ErrorActionPreference = "Stop"

# CRITICAL: Enforce TLS 1.2 for HTTPS downloads (required for GitHub)
# Older PowerShell versions default to TLS 1.0 which GitHub no longer supports
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration
$WindowsExporterPort = $NodeExporterPort
$WindowsExporterInstallDir = "C:\Program Files\windows_exporter"
$WindowsPkg = "windows_exporter-$WindowsExporterVersion-amd64"
$WindowsUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v$WindowsExporterVersion/$WindowsPkg.msi"
$WindowsInstallerPath = "C:\Temp\windows_exporter.msi"

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Main deployment function
function Deploy-WindowsExporter {
    Write-Info "=========================================="
    Write-Info "StackWatch Windows Exporter Deployment"
    Write-Info "=========================================="
    Write-Info ""
    Write-Info "CRITICAL: PowerShell script only - NO Ansible"
    Write-Info "Port: $WindowsExporterPort"
    Write-Info "Version: $WindowsExporterVersion"
    Write-Info ""
    
    # Check if running as Administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "This script must be run as Administrator"
        exit 1
    }
    
    # Ensure temp directory exists
    Write-Info "Creating temp directory..."
    if (-not (Test-Path "C:\Temp")) {
        New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
    }
    
    # Check if Windows Exporter is already installed
    Write-Info "Checking for existing Windows Exporter installation..."
    $existingService = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
    
    if ($existingService) {
        Write-Warn "Windows Exporter service already exists"
        Write-Info "Stopping existing service..."
        Stop-Service -Name "windows_exporter" -Force -ErrorAction SilentlyContinue
    }
    
    # Download Windows Exporter MSI
    Write-Info "Downloading Windows Exporter MSI..."
    try {
        Invoke-WebRequest -Uri $WindowsUrl -OutFile $WindowsInstallerPath -UseBasicParsing
        Write-Info "Download complete: $WindowsInstallerPath"
    }
    catch {
        Write-Error "Failed to download Windows Exporter: $_"
        exit 1
    }
    
    # Install Windows Exporter MSI
    Write-Info "Installing Windows Exporter MSI (silent mode)..."
    $installArgs = "/quiet ENABLE_LISTENER=y LISTEN_PORT=$WindowsExporterPort"
    
    try {
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$WindowsInstallerPath`" $installArgs" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Info "Windows Exporter MSI installed successfully (Exit code: $($process.ExitCode))"
        }
        else {
            Write-Error "Windows Exporter MSI installation failed (Exit code: $($process.ExitCode))"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to install Windows Exporter: $_"
        exit 1
    }
    
    # Configure Windows Exporter service to start automatically
    Write-Info "Configuring Windows Exporter service..."
    try {
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='windows_exporter'"
        if ($service) {
            $service.ChangeStartMode("Automatic") | Out-Null
            Start-Service -Name "windows_exporter" -ErrorAction Stop
            Write-Info "Windows Exporter service configured and started"
        }
        else {
            Write-Error "Windows Exporter service not found after installation"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to configure Windows Exporter service: $_"
        exit 1
    }
    
    # Wait for service to be ready
    Write-Info "Waiting for service to be ready..."
    Start-Sleep -Seconds 5
    
    # Configure Windows Firewall
    if (-not $SkipFirewall) {
        Write-Info "Configuring Windows Firewall..."
        
        # Check if firewall rule already exists
        $existingRule = Get-NetFirewallRule -DisplayName "Windows Exporter $WindowsExporterPort" -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Warn "Removing existing firewall rule..."
            Remove-NetFirewallRule -DisplayName "Windows Exporter $WindowsExporterPort" -ErrorAction SilentlyContinue
        }
        
        # Create new firewall rule
        try {
            New-NetFirewallRule -DisplayName "Windows Exporter $WindowsExporterPort" `
                -Direction Inbound `
                -LocalPort $WindowsExporterPort `
                -Protocol TCP `
                -Action Allow `
                -Enabled True `
                -Profile Domain,Private,Public | Out-Null
            
            Write-Info "Firewall rule created successfully"
        }
        catch {
            Write-Warn "Failed to create firewall rule: $_"
            Write-Warn "Please manually allow port $WindowsExporterPort in Windows Firewall"
        }
    }
    else {
        Write-Warn "Firewall configuration skipped (SkipFirewall flag set)"
    }
    
    # Wait for Windows Exporter to start listening
    Write-Info "Waiting for Windows Exporter to start listening on port $WindowsExporterPort..."
    $maxRetries = 30
    $retryCount = 0
    $listening = $false
    
    while ($retryCount -lt $maxRetries -and -not $listening) {
        try {
            $connection = Test-NetConnection -ComputerName localhost -Port $WindowsExporterPort -WarningAction SilentlyContinue
            if ($connection.TcpTestSucceeded) {
                $listening = $true
                Write-Info "Windows Exporter is listening on port $WindowsExporterPort"
            }
        }
        catch {
            # Continue retrying
        }
        
        if (-not $listening) {
            Start-Sleep -Seconds 1
            $retryCount++
        }
    }
    
    if (-not $listening) {
        Write-Warn "Windows Exporter may not be listening on port $WindowsExporterPort - check manually"
    }
    
    # Verify service status
    Write-Info "Verifying Windows Exporter service status..."
    $service = Get-Service -Name "windows_exporter" -ErrorAction SilentlyContinue
    
    if ($service) {
        $serviceInfo = Get-WmiObject -Class Win32_Service -Filter "Name='windows_exporter'"
        Write-Info "Service Status: $($service.Status)"
        Write-Info "Service Start Mode: $($serviceInfo.StartMode)"
        Write-Info "Auto-Start on Boot: $(if ($serviceInfo.StartMode -eq 'Auto') { 'YES' } else { 'NO' })"
    }
    else {
        Write-Error "Windows Exporter service not found"
        exit 1
    }
    
    # Get Windows hostname and IP address
    $hostname = $env:COMPUTERNAME
    $ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress
    if (-not $ipAddress) { $ipAddress = "127.0.0.1" }
    
    # Display summary
    Write-Info ""
    Write-Info "=========================================="
    Write-Info "Windows Exporter Installation Summary"
    Write-Info "=========================================="
    Write-Info "Version: $WindowsExporterVersion"
    Write-Info "Port: $WindowsExporterPort"
    Write-Info "Install Directory: $WindowsExporterInstallDir"
    Write-Info "Hostname: $hostname"
    Write-Info "IP Address: $ipAddress"
    Write-Info "Service Status: $($service.Status)"
    Write-Info "Service Start Mode: $($serviceInfo.StartMode)"
    Write-Info "Auto-Start on Boot: $(if ($serviceInfo.StartMode -eq 'Auto') { 'YES' } else { 'NO' })"
    Write-Info "Port Status: $(if ($listening) { 'Listening' } else { 'Not listening - check manually' })"
    Write-Info "HTTP Endpoint: http://${ipAddress}:${WindowsExporterPort}/metrics"
    Write-Info "=========================================="
    Write-Info ""
    Write-Info "To verify service configuration manually:"
    Write-Info "  Get-Service windows_exporter"
    Write-Info "  Get-WmiObject -Class Win32_Service -Filter \"Name='windows_exporter'\" | Select-Object Name, State, StartMode"
    Write-Info ""
    Write-Info "Windows Exporter deployment complete!"
    
    # Clean up installer
    if (Test-Path $WindowsInstallerPath) {
        Write-Info "Cleaning up installer..."
        Remove-Item -Path $WindowsInstallerPath -Force -ErrorAction SilentlyContinue
    }
}

# Run deployment
Deploy-WindowsExporter

