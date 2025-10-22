<#
.SYNOPSIS
  Download Device42 agent from GitHub, save to C:\ProgramData\Device42,
  run it once immediately, then register a weekly scheduled task at 6:00 AM SGT.
#>

# --- CONFIGURATION SECTION ---
$TaskName     = "Device42WeeklyTask"
$TaskDesc     = "Runs Device42 discovery task at 6:00 AM SGT"
$ExeFileName  = "d42_winagent_x64.exe"
$TargetFolder = "C:\ProgramData\Device42"
$ExePath      = Join-Path -Path $TargetFolder -ChildPath $ExeFileName
$DownloadUrl  = "https://github.com/mohdyazidms/d42/releases/download/v1/d42_winagent_x64.exe"
$TriggerTime  = "06:00"   # Time for scheduled task

# --- DOWNLOAD AND PREPARE EXECUTABLE ---
try {
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

# --- RUN THE PROGRAM ONCE IMMEDIATELY ---
try {
    Start-Process -FilePath $ExePath -ArgumentList "/silent" -Wait
    Write-Output "✅ Program executed successfully once."
}
catch {
    Write-Error "❌ Failed to run the program: $($_.Exception.Message)"
    exit 1
}

# --- CREATE / RECREATE THE SCHEDULED TASK ---
try {
    # Remove existing task if found
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Define the action (run .exe silently)
    $Action = New-ScheduledTaskAction -Execute $ExePath -Argument "/silent"

    # Define the trigger (weekly Monday at $TriggerTime)
    $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $TriggerTime

    # Define settings
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    # Define SYSTEM principal
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    # Register the scheduled task
    Register-ScheduledTask -TaskName $TaskName -Description $TaskDesc -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force

    Write-Output "✅ Scheduled task '$TaskName' created to run weekly at $TriggerTime."
}
catch {
    Write-Error "❌ Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}
