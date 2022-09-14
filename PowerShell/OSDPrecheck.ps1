function writemsg
{
    $global:index++
    write-host "($index) $msg" -ForegroundColor $color
    Write-Output $msg | Out-File $logfile -append
    $global:msg=""
    Start-Sleep 1
}
function readmsg($m,$c)
{
    if($c -eq 1)
    {
        $global:color="green"
    }
    if($c -eq 0)
    {
        $global:color="red"
    }
    if($c -eq 2)
    {
        $global:color="yellow"
    }
    $global:msg="$m [$(get-date -format G)]"
    writemsg
}
function isPartOfImageCollection
{
    if((Invoke-RestMethod -Method get -Uri "https://$SCCMServerName/AdminService/wmi/SMS_FullCollectionMembership?`$filter=collectionid eq '$collectionid'" -Credential $cred).value | Where-Object { $_.resourceid -eq $resourceid})
    {
        return $true
    }
    else 
    {
        return $false
    }
}
function checkDeviceMembership
{
    $attempt=0
    $deviceAddedToCollection=$null
    readmsg "Checking device membership in image deployment group." 2
    write-host "Performing attempts to add in database --->" -nonewline 
    do 
    {
        $attempt++
        write-host "$attempt " -nonewline 
        $deviceAddedToCollection=$null
        if(isPartOfImageCollection)
        {
            $deviceAddedToCollection=$true
            break
        }
        else
        {
            Start-Sleep 20
        }
    } while ($true -and $attempt -le 20)
    write-host ""
    if(!$deviceAddedToCollection)
    {
        readmsg "Failed to check the membership. Please contact admin to ensure the device is part of collection and then proceed with deployment." 0
        return $false
    }
    else 
    {
        readmsg "Successfully added the device to imaging group." 1
        return $true
    }
}
function isPartOfRootCollection
{
    if((Invoke-RestMethod -Method get -Uri "https://$SCCMServerName/AdminService/wmi/SMS_FullCollectionMembership?`$filter=collectionid eq 'SMS00001'" -Credential $cred).value | Where-Object { $_.resourceid -eq $resourceid})
    {
        return $true
    }
    else 
    {
        return $false
    }
}
function addDeviceToSCCMCollection
{
    try 
    {
        $filter= @{
                collectionRule = @{
                "@odata.type"     = "#AdminService.SMS_CollectionRuleDirect"
                ResourceClassName = "SMS_R_System"
                ResourceID        = [int]$ResourceID
            }
        }
        readmsg "Adding device $LocalComputername in image deployment group" 2
        Invoke-RestMethod -Method Post -Uri "https://$SCCMServerName/AdminService/wmi/SMS_Collection('$collectionid')/AdminService.AddMembershipRule" -Credential $cred -Body $($filter | ConvertTo-Json) -ContentType "application/json" | Out-Null
        readmsg "Successfully initiated device $LocalComputername membership in image deployment group. $?" 1
        return checkDeviceMembership
    }
    catch 
    {
        readmsg "Device $LocalComputername having resource id $resourceid failed to add in image deployment group. $?" 0
        readmsg $_ 0
        return $false
    }
}

function getSCCMDeviceByMACAddress
{
    try
    {
        $cmDevice=$null
        readmsg "Checking if any device exist in database against MACAddress $ethernetmacaddress" 2
        $cmDevice = (Invoke-RestMethod "https://$SCCMServerName/AdminService/V1.0/Device?`$select=MachineId,Name,MACAddress" -Credential $Cred -ErrorAction Stop).value | where-object{$_.MacAddress -match $ethernetmacaddress}
        if($null -ne $cmDevice)
        {
            $cmDeviceName=$cmDevice.name
            if($cmDeviceName.count -gt 1)
            {
                $q=0
                readmsg "Multiple entries found for $ethernetmacaddress" 2
                foreach($d in $cmDevice)
                {
                    $q++
                    Write-Host "`t $q --> $($d.name) : $($d.machineid)"
                }
                #deleteCMDevice $($cmDevice | Where-Object { $_.client -eq 0})
            }
            $global:resourceid=$cmDevice.machineid
            readmsg "Device $cmDeviceName is found in database against MACAddress $ethernetmacaddress having resource id as $resourceid." 1
            if(!(isPartOfImageCollection))
            {
                if(addDeviceToSCCMCollection)
                {
                    readmsg "Device Added to database." 1
                    return "Device Added to database."
                }
                else
                {
                    return "Failed to add device having MACAddress $ethernetmacaddress to database."
                }
            }
            else 
            {
                readmsg "Device already part of the imaging group." 1
                return "Device Added to database."
            }
        }
        else 
        {
            readmsg "No device found against MACAddress $ethernetmacaddress in database." 1
            return "No device found against MACAddress $ethernetmacaddress in database."
        }
    }
    catch
    {
        readmsg "Failed to get Device information by MACAddress from database." 0
        readmsg $_ 0
        return "Failed to get Device information by MACAddress $ethernetmacaddress from database."
    }
}

function checkBiosPassword
{
    $manufacturer=(Get-WmiObject win32_bios).manufacturer
    if($manufacturer -eq 'HP' -or $manufacturer -eq 'HPE' -or $manufacturer -eq 'Hewlett-Packard')
    {
        $hpbiospassword=(Get-WmiObject -Namespace root/hp/InstrumentedBIOS -Class HP_BIOSSetting | Where-Object {$_.name -match 'setup password'}).isset
        if($hpbiospassword -eq 1)
        {
            $global:biospassword=$true
        }
    }
    if($manufacturer -eq 'Dell')
    {
        $dellbiospassword=(Get-CimInstance -Namespace root/dcim/sysman -ClassName DCIM_BIOSPassword -Filter "AttributeName='AdminPwd'").isSet
        if($dellbiospassword -eq 'True')
        {
            $global:biospassword=$true
        }
    }
    if($manufacturer -eq 'Lenovo')
    {
        $lenovobiospassword=(Get-WmiObject -Class Lenovo_BiosPasswordSettings -Namespace root\wmi).PasswordState
        if($lenovobiospassword -eq 2)
        {
            $global:biospassword=$true
        }
    }
    if($global:biospassword)
    {
        readmsg "Manufacturer : $manufacturer --> BIOS Password is set." 0
    }
}

$orgname=""
$global:biospassword=$false
$global:proceedWithImage=$true
$global:deviceimported=$false
$global:collectionid=""
$ts=New-Object -ComObject Microsoft.SMS.TSEnvironment
Clear-Host
if($null -ne $ts)
{
    $Logfile = 'x:\windows\temp\smstslog\WindowsDeploymentCustom.log'
}
else 
{
    $Logfile = 'c:\windows\temp\WindowsDeploymentCustom.log'
}
$DomainUser=''
$domainPassword=''
$global:SCCMServerName=''
$global:SCCMNameSpace=''
$global:ethernetmacaddress=(Get-WmiObject win32_networkadapter | Where-Object {$_.physicaladapter -eq $true -and $_.netconnectionstatus -eq 2} ).macaddress
$securePassword = ConvertTo-SecureString $domainPassword -AsPlainText -Force
$global:Cred = New-Object System.Management.Automation.PSCredential ($DomainUser, $securePassword)
$global:index=0
$global:msg=""
$global:color=""
$global:scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$global:resourceid=$null
$url=""
New-PSDrive -Name 'M' -PSProvider FileSystem -Root $url  -Persist -Credential $Cred | Out-Null
Write-Output "SECTION START : Imaging Precheck. : $(Get-Date)" | Out-File $logfile -append
Write-Host "*******************************************************************************************" -ForegroundColor cyan
Write-Host "************************** $orgname GLobal SOE Imaging ************************************" -ForegroundColor Cyan
Write-Host "*******************************************************************************************" -ForegroundColor cyan
Write-Host ""
if($($global:ethernetmacaddress).count -gt 1)
{
    $global:ethernetmacaddress=$global:ethernetmacaddress[0]
}
readmsg "Current device ethernet MAC address : $global:ethernetmacaddress" 1
$deviceExistinSCCM=getSCCMDeviceByMACAddress
$message=""
write-host ""
$i=0
readmsg "Checking BIOS password...." 2
checkBiosPassword
readmsg "Checking PowerAdaptor connection...." 2
$BatteryStatus =  (Get-WmiObject -Class win32_battery).BatteryStatus
readmsg "Checking Disk information...." 2
$listdisk=Get-Disk
$HDDList = (GET-WMIOBJECT -Query "select * from Win32_DiskDrive where not pnpdeviceid like 'usb%'")
if ($HDDList -is [array]){$numberOfDisk = $HDDList.count}
readmsg "Checking Netowork connection...." 2
$netstatus=get-wmiobject win32_networkadapter -filter "netconnectionstatus = 2" | Select-Object netconnectionid, name, InterfaceIndex, netconnectionstatus
if($deviceExistinSCCM -ne "Device Added to database.")
{
    $i++
    $message+="`n $i --> $deviceExistinSCCM Please contact Administrator to get the device registered/updated in database."
    $global:proceedWithImage=$false
}
if($BatteryStatus -ne 2)
{
    $i++
    $message+="`n $i --> Device is not connected with Power Adaper cable. Please connect power cable."
    $global:proceedWithImage=$false
}
if(!$listdisk)
{
    $i++
    $message+="`n $i --> Disk is not getting detected."
    $global:proceedWithImage=$false
}
if($numberOfDisk -gt 1)
{
    $i++
    $message+="`n $i --> Multiple disk detected in this computer. Under certain circumstances the installation can erase wrong partitions. Please make sure you have backed up all your data or please remove the additional drives before continuing!"
    $global:proceedWithImage=$false
}
if($null -eq $netstatus)
{
    $i++
    $message+="`n $i --> No network detected. Please connect LAN cable with corporate network."
    $global:proceedWithImage=$false
}
if($biospassword)
{
    $i++
    $message+="`n $i --> Device have password set. Please clear the BIOS password."
    $global:proceedWithImage=$false
}
Write-Output "SECTION END : Imaging Precheck. : $(Get-Date)" | Out-File $logfile -append
if($proceedWithImage)
{
    Write-Host ""
    Write-Host "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^" -ForegroundColor Black -BackgroundColor White
    write-host "^ You are good to go with Imaging process. Console will close automatically in 5 seconds. ^" -ForegroundColor Black -BackgroundColor White
    Write-Host "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^" -ForegroundColor Black -BackgroundColor White
    write-host ""
    Write-Host "*******************************************************************************************" -ForegroundColor cyan
    Start-Sleep 5
    Exit
}
else 
{
    write-host ""
    Write-Host "Some of the issues found during pre-check as listed below." -ForegroundColor Magenta
    Write-Host $message -ForegroundColor Yellow -BackgroundColor red
    write-host ""
    Write-Host "Available options"
    Write-Host "1. Continue anyway."
    Write-Host "2. Restart device."
    Write-Host "3. Shutdown device."
    write-host ""
    $choice=Read-Host -Prompt "Provide your input."
    if($choice -eq 1)
    {
        Exit
    }
    if($choice -eq 2)
    {
        wpeutil reboot
    }
    if($choice -eq 3)
    {
        wpeutil shutdown
    }
}

