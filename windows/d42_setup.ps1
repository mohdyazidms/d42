<#
.SYNOPSIS
  Download Device42 agent from GitHub, save to C:\ProgramData\Device42,
  and register a weekly scheduled task to run it at 6:00 AM SGT.
#>

# --- CONFIGURATION SECTION ---
$TaskName     = "Device42WeeklyTask"
$TaskDesc     = "Runs Device42 discovery task at 6:00 AM SGT"
$ExeFileName  = "d42_winagent_x64.exe"
$TargetFolder = "C:\ProgramData\Device42"
$ExePath      = Join-Path -Path $TargetFolder -ChildPath $ExeFileName
$StartTimeSGT = "06:00"
$DownloadUrl  = "https://github.com/mohdyazidms/d42/releases/download/v1/d42_winagent_x64.exe"

# --- DOWNLOAD AND PREPARE EXECUTABLE ---
try {
    # Ensure modern TLS for GitHub
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Create target folder if it doesn't exist
    if (-not (Test-Path -Path $TargetFolder)) {
        New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
    }

    # Remove existing file if present
    if (Test-Path -Path $ExePath) {
        Remove-Item -Path $ExePath -Force
    }

    # Set User-Agent header for GitHub
    $headers = @{ 'User-Agent' = 'PowerShell' }

    # Download the file silently
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -Headers $headers -UseBasicParsing -ErrorAction Stop

    # Validate file
    if (-not ((Test-Path -Path $ExePath) -and ((Get-Item $ExePath).Length -gt 0))) {
        throw "Download failed or file is empty: $ExePath"
    }
}
catch {
    Write-Error "❌ Download failed: $($_.Exception.Message)"
    exit 1
}

# --- CREATE THE SCHEDULED TASK ---
try {
    # Define the action
    $Action = New-ScheduledTaskAction -Execute $ExePath

    # Define the trigger
    $Trigger = New-ScheduledTaskTrigger -Weekly -At $StartTimeSGT

    # Ensure it runs if it missed the schedule
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

    # Run under SYSTEM account with highest privileges
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    # Register the task silently
    Register-ScheduledTask -TaskName $TaskName -Description $TaskDesc -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force
}
catch {
    Write-Error "❌ Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}
