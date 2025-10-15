<#
    Script Name: Install-D42Agent.ps1
    Description: Downloads and installs the Device42 Windows Agent silently from your Gitea repository.
                 Adds a permanent Windows Firewall rule to allow TCP 3000 from 110.4.41.172.
    Author: Khuzaini Mohamed
    Date: 2025-10-07
#>

# ================= CONFIGURATION =================
$repoURL = "http://110.4.41.172:3000/mydc/mydc-scripts/raw/branch/main/common/d42_winagent_x64.exe"
$downloadPath = "C:\ProgramData\Device42"
$installerFile = Join-Path $downloadPath "d42_winagent_x64.exe"
$logFile = Join-Path $downloadPath "Install-D42Agent.log"
$arguments = "/S"   # Silent install switch for Device42 agent
$sourceIP = "110.4.41.172"
$port = 3000
$firewallRuleName = "Allow TCP 3000 from $sourceIP (Device42 Gitea Access)"

# ================= PREPARATION ===================
if (-not (Test-Path -LiteralPath $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
}

Start-Transcript -Path $logFile -Append | Out-Null
Write-Host "`n=== Device42 Windows Agent Installer ===`n"

# Verify Admin Rights
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error " Please run this script as Administrator."
    Stop-Transcript | Out-Null
    exit 1
}

# ================= FIREWALL CONFIG ==================
Write-Host "Configuring Windows Firewall to permanently allow TCP port $port from $sourceIP..."
try {
    # Remove existing rule if it already exists
    if (Get-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -DisplayName $firewallRuleName -ErrorAction SilentlyContinue
    }

    # Create a permanent inbound rule for Gitea access
    New-NetFirewallRule -DisplayName $firewallRuleName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $port `
        -RemoteAddress $sourceIP `
        -Profile Any `
        -Description "Permanent rule added by Device42 installer to allow Gitea communication on port $port." `
        | Out-Null

    Write-Host "  Permanent firewall rule added successfully."
} catch {
    Write-Warning "  Firewall configuration failed: $_"
}

# ================= DOWNLOAD ======================
Write-Host "Downloading Device42 Agent from Gitea..."
try {
    Invoke-WebRequest -Uri $repoURL -OutFile $installerFile -UseBasicParsing -TimeoutSec 300
    Write-Host "  Download completed: $installerFile"
} catch {
    Write-Error "  Download failed: $_"
    Stop-Transcript | Out-Null
    exit 1
}

# ================= INSTALLATION ==================
if (Test-Path -LiteralPath $installerFile) {
    Write-Host "Starting silent installation..."
    try {
        $process = Start-Process -FilePath $installerFile -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "  Device42 Agent installed successfully."
        } else {
            Write-Warning "  Installation completed with exit code $($process.ExitCode)."
        }
    } catch {
        Write-Error "  Installation failed: $_"
    }
} else {
    Write-Error "  Installer not found after download."
}

# ================= CLEANUP =======================
try {
    if (Test-Path -LiteralPath $installerFile) {
        Remove-Item -LiteralPath $installerFile -Force
        Write-Host "  Cleaned up downloaded installer."
    }
} catch {
    Write-Warning "  Cleanup failed: $_"
}

# ================= FINALIZE =======================
Stop-Transcript | Out-Null
Write-Host "`nInstallation log saved at: $logFile"
Write-Host "Permanent Firewall Rule: '$firewallRuleName' (TCP $port from $sourceIP)"
Write-Host "==========================================="
