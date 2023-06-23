$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$logfile = "$($tsenv.Value('_SMSTSLogPath'))\WindowsDeploymentCustom.log"
Write-Output "SECTION START : Setting proper disk number for formatting : $(Get-Date)" | Out-File $logfile -append
Write-Output "" | Out-File $logfile -append
$listdisk=get-physicaldisk | Select-Object DeviceID,FileSystem,Friendlyname,Manufacturer,Model,SerialNumber,Size,BusType,MediaType,OperationalStatus
$osDiskNumber=$null
$listdisk | Out-File $logfile -append
Write-Output "" | Out-File $logfile -append
if($null -ne $listdisk)
{
    if($listdisk.count -gt 1)
    {
        Write-Output "More than 1 disk exists." | Out-File $logfile -append
        $nonUSBDisks=$listdisk | Where-Object { $_.BusType -ne 'USB'} 
        if($null -ne $nonUSBDisks)
        {
            if($nonUSBDisks.count -gt 1)
            {
                $osDiskNumber=($nonUSBDisks | Sort-Object -Property Size | Select-Object -First 1).DeviceID
            }
            else 
            {
                $osDiskNumber=$nonUSBDisks.DeviceID
            } 
        }
        else 
        {
            Write-Output "No NON-USB disks available." | Out-File $logfile -append
            $osDiskNumber=10
        }
        $TSEnv.Value("OSDDiskIndex") = $osDiskNumber
    }
    else 
    {
        Write-Output "Only one disk available." | Out-File $logfile -append
        if(($listdisk | Where-Object { $_.BusType -ne 'USB'}).count -eq 0)
        {
            $osDiskNumber=10
            $TSEnv.Value("OSDDiskIndex") = $osDiskNumber
            Write-Output "Only USB disk." | Out-File $logfile -append
        }

    }
    Write-Output "OS DISK number set = $($TSEnv.Value("OSDDiskIndex"))" | Out-File $logfile -append
}
else 
{
    Write-Output "No disks available." | Out-File $logfile -append
}
Write-Output "SECTION END : Setting proper disk number for formatting : $(Get-Date)" | Out-File $logfile -append
