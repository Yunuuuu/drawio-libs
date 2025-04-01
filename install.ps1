# Self elevating PowerShell script
# come from 
#   ** https://superuser.com/questions/747254/powershell-elevation-loses-current-directory
#   ** https://stackoverflow.com/questions/7690994/running-a-command-as-administrator-using-powershell

# $Delay = 5
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] 'Administrator')
) {
    # Write-Host "Not elevated, restarting in $Delay seconds ..."
    # Start-Sleep -Seconds $Delay
    Write-Host "Not elevated, starting PowerShell with admin rights"

    $Arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-NoExit",
        "-File",
        "`"$($MyInvocation.MyCommand.Path)`""
    )
    Start-Process -FilePath PowerShell.exe -Verb RunAs -WorkingDirectory $pwd -ArgumentList $Arguments

    # Exit from the current, unelevated, process
    Exit
}

# For powershell script, we must trigger it at user logon, but we want it 
# executed when system boot, so we also set user logon when system boot
# automatically.
# https://answers.microsoft.com/en-us/windows/forum/all/how-to-login-automatically-to-windows-11/c0e9301e-392e-445a-a5cb-f44d00289715
# 1. turn Off the For improved security, only allow Windows Hello sign-in for Microsoft accounts on this device option.
#    If this option is greyed out, you can sign out and then sign in back to change it.
# 2. Press Windows + R and select Run, type `netplwiz` command.
# 3. In User Accounts window, on Users tab, uncheck the Users must enter a user name and password to use this computer option.
#
# Customise the XML used to create a scheduled task, then create the task.
#
# Prepare global variables and function -------------------------
function RegisterScheduledTask {
    param(
        [Parameter(Position = 0)][string]$name, 
        [Parameter(Position = 1)]$Task
    )
    try {
        $xml_content = [xml](Export-ScheduledTask -InputObject $Task)
        $TempFile = New-TemporaryFile
        $xml_content.Save($TempFile)
        sudo schtasks /create /TN $name /XML $TempFile
    }
    finally {
        <#Do this after the try block regardless of whether an exception occurred or not#>
        # Write-Host "$TempFile"
        Remove-Item $TempFile
    }
}

$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger `
    -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger

$Stset = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopIfGoingOnBatteries `
    -WakeToRun `
    -DontStopOnIdleEnd `
    -RestartOnIdle `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 3

$UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Principal = New-ScheduledTaskPrincipal `
    -UserId $ENV:USERNAME `
    -LogonType "S4U" `
    -RunLevel "Limited" #Limited

$Action = New-ScheduledTaskAction `
    -Execute git `
    -Argument '--git-dir="$PSScriptRoot/.git" pull'

$Trigger = New-ScheduledTaskTrigger -Daily
$Trigger.Delay = "PT15S"
$MyStset = $Stset.Clone()
$MyStset.RunOnlyIfNetworkAvailable = $true
$Task = New-ScheduledTask `
    -Trigger $Trigger `
    -Action $Action `
    -Settings $MyStset `
    -Principal $Principal `
    -Description "Update drawio library in the backgroud"

RegisterScheduledTask "drawio-libs" $Task
