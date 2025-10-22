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
$DownloadUrl  = "https://github.com/mohdyazidms/d42/releases/download/v1/d42_winagent_x64.exe"

# --- PARSE TIME SAFELY (06:00) ---
$timeString = "06:00"
$StartTime = [datetime]::Today.AddHours([int]($timeString.Split(':')[0])).AddMinutes([int]($timeString.Split(':')[1]))

# --- DOWNLOAD AND PREPARE EXECUTABLE ---
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not (Test-Path -Path $TargetFolder)) {
        New-Item -Path $TargetFolder -ItemType Directory -Force | Out-Null
    }

    if (Test-Path -Path $ExePath) {
        Remove-Item -Path $ExePath -Force
    }

    $headers = @{ 'User-Agent' = 'PowerShell' }

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ExePath -Headers $headers -UseBasicParsing -ErrorAction Stop

    if (-not ((Test-Path -Path $ExePath) -and ((Get-Item $ExePath).Length -gt 0))) {
        throw "Download failed or file is empty: $ExePath"
    }
}
catch {
    Write-Error "❌ Download failed: $($_.Exception.Message)"
    exit 1
}

# --- CREATE / RECREATE THE SCHEDULED TASK ---
try {
    # Remove existing task if found
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    # Define the action (run .exe directly)
    $Action = New-ScheduledTaskAction -Execute $ExePath

    # Define the trigger properly (weekly)
    $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "06:00"

    # Define settings
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    # Define SYSTEM principal
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    # Register the task
    Register-ScheduledTask -TaskName $TaskName -Description $TaskDesc -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force

    Write-Output "✅ Scheduled task '$TaskName' created successfully to run weekly at $timeString."
}
catch {
    Write-Error "❌ Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}
