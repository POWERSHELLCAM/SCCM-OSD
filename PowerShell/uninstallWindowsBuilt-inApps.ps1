<#
.SYNOPSIS
    Remove builtin apps
   
.DESCRIPTION
    The script will uninstall the Windows built-in application Onenote and Outlook. The new list can be updated in $AppsList.

.NOTES
    Version: 1.0
    Original Author: Shishir Kushawaha
    Modifiedby: Shishir Kushawaha
    Email: srktcet@gmail.com
    Date Created: 18-07-2020
#>

#region Variable declaration
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$logfile = "$($tsenv.Value('_SMSTSLogPath'))\Windows10DeploymentCustom.log"
$AppsList = "Microsoft.Office.OneNote","microsoft.windowscommunicationsapps" #As example, uninstalling outlook and onenote
#endregion Variable declaration

Write-Output "" | Out-File $logfile -append
Write-Output "SECTION START : Uninstall Built-in Application. : $(Get-Date)" | Out-File $logfile -append

#region *** Install FOD Packages ***
ForEach ($App in $AppsList) 
{
    $PackageFullName = (Get-AppxPackage -AllUsers $App).PackageFullName
    $ProPackageFullName = (Get-AppxProvisionedPackage -online | Where-Object {$_.Displayname -eq $App}).PackageName
    write-host $PackageFullName
    Write-Host $ProPackageFullName
    if ($PackageFullName) 
    {
        Write-Output "Removing Package: $app" | Out-File $logfile -append
        remove-AppxPackage -package $PackageFullName -Verbose -ErrorAction SilentlyContinue
        Write-Output "Removing Package: $app - exit code $?" | Out-File $logfile -append
    } 
    if ($ProPackageFullName) 
    {
        Write-Output "Removing Provisioned Package: $ProPackageFullName" | Out-File $logfile -append
        Remove-AppxProvisionedPackage -online -packagename $ProPackageFullName -Verbose -ErrorAction SilentlyContinue
        Write-Output "Removing Provisioned Package: $ProPackageFullName - exit code $?" | Out-File $logfile -append
    } 
    # Unable to find app in either list
    If (($null -eq $PackageFullName) -and ($null -eq $ProPackageFullName)) 
    {
        Write-output "`"$App`" is not in either AppxPackage or AppxProvisionedPackage list" | Out-File $logfile -append
    }
}
#endregion *** Install FOD Packages ***
Write-Output "SECTION END : Uninstall Built-in Application. : $(Get-Date)" | Out-File $logfile -append
