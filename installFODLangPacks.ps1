<#
.SYNOPSIS
    Install Feature On Demand basic package.
   
.DESCRIPTION
    The MDT wizard will have the option to select the language to install. Technician selection will be recorded in UILanguage task sequence variable. 
    This script will read this variable and use Get-WindowsCapability to get the FOD pack and Add-WindowsCapability to install it.
.NOTES
    Version: 1.0
    Original Author: Shishir Kushawaha
    Modifiedby: Shishir Kushawaha
    Email: Shishir.Kushawaha@manpowergroup.com    
    Date Created: 22-07-2022
#> 

#region variable declaration
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$logfile = "$($tsenv.Value('_SMSTSLogPath'))\Windows10DeploymentCustom.log"
$language=$tsenv.Value('UILanguage')
#endregion variable declaration
Write-Output "" | Out-File $logfile -append
Write-Output "SECTION START : Feature on Demand Pack Installation. : $(Get-Date)" | Out-File $logfile -append

# Reset WindowsUpdate key
cmd.exe /c "REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /V UseWUServer /T REG_DWORD /D 0 /F
Write-Output "Set WindowsUpdate key to `"0`", exit code: $?" | Out-File $logfile -append

Restart-Service wuauserv -Verbose
Write-Output "Restarting the Windows Update service `"wuauserv`", exit code: $?" | Out-File $logfile -append

#region *** Install FOD Packages ***
Write-Output "User have selectec $language language from UDI wizard." | Out-File $logfile -append
Write-Output "Installing basic FOD for $language" | Out-File $logfile -append
try 
{
    Get-WindowsCapability -Online | Where-Object{($_.Name -match $language) -and ($_.Name -match "basic")} |Add-WindowsCapability -Online -Verbose -ErrorAction SilentlyContinue
    Write-Output "Injecting FOD package, exit code: $?" | Out-File $logfile -append
}
catch [exception]
{
    Write-output "Failed to install lnaguge FOD package." | Out-File $logfile -append
    Write-output $_ | Out-File $logfile -append
}
#endregion *** Install FOD Packages ***

# Reset WindowsUpdate key
cmd.exe /c "REG ADD HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /V UseWUServer /T REG_DWORD /D 1 /F
Write-Output "Set WindowsUpdate key to `"0`", exit code: $?" | Out-File $logfile -append
   
# Restart service
Restart-Service wuauserv -Verbose
Write-Output "Restarting the Windows Update service `"wuauserv`", exit code: $?" | Out-File $logfile -append
Write-Output "SECTION END: Feature on Demand Pack Installation. : $(Get-Date)" | Out-File $logfile -append
Write-Output "" | Out-File $logfile -append
