# --- CONFIGURATION SECTION ---
$TaskName     = "Device42WeeklyTask"
$TaskDesc     = "Runs Device42 discovery task at 6:00 AM SGT"
$ExePath      = "C:\ProgramData\Device42\d42_winagent_x64.exe"
$StartTimeSGT = "06:00"

# --- CREATE THE SCHEDULED TASK ---
# Define the action
$Action = New-ScheduledTaskAction -Execute $ExePath

# Define the trigger
$Trigger = New-ScheduledTaskTrigger -Weekly -At $StartTimeSGT

# Ensure it runs if it missed the schedule
$Settings = Device42-TaskSettingsSet -StartWhenAvailable

# Run under SYSTEM account with highest privileges
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

# Register the task
Register-ScheduledTask -TaskName $TaskName -Description $TaskDesc -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Force
