<#
.SYNOPSIS
    Get the application and package list from UDI wizard
   
.DESCRIPTION
    This script will prepare the list of applications selected during UDI wizard. The list will be stored in udiapplist task sequence variable and
    UDISelectedApps.log log file for further references. 

.NOTES
    Version: 1.0
    Original Author: Shishir Kushawaha
    Modifiedby: Shishir Kushawaha
    Email: srktcet@gmail.com    
    Date Created: 05-08-2022
#> 

#region variable declarartion 
$tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
$var="Applications001"
$LogPath = $tsenv.Value("_SMSTSLogPath")
$logfile = "$LogPath\WindowsDeploymentCustom.log"
$appfile = "$LogPath\UDISelectedApps.log"
$applist=""
$i=1
#endregion variable declarartion 

#region processing application list
Write-Output " " | Out-File $logfile -append
Write-Output "SECTION START : Capture Applications list. : $(Get-Date)" | Out-File $logfile -append
while(($($tsenv.Value($var)) -ne ""))
{
    if($i -eq 1)
    {
        $applist=$($tsenv.Value($var))
        $applist | out-file $appfile -append
    }
    else
    {
        $($tsenv.Value($var)) | out-file $appfile -append
        $applist=$applist+","+$($tsenv.Value($var))
    }
    $var="Applications00"
    $i++
    $var="$var"+"$i"
}
$tsenv.Value('udiapplist')=$applist
$applist | Out-File $logfile -append
Write-Output "SECTION END : Capture Applications list. : $(Get-Date)" | Out-File $logfile -append
#endregion processing application list
