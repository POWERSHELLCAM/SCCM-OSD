$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$TSLogpath = $tsenv.Value("_SMSTSLogPath")
$logFiles=(Get-ChildItem "$TSLogpath\smsts*.log").FullName
$outputLogFile="$TSLogpath\compressedSMSTSLogFile.log"
$values = @("Start executing an instruction. Instruction name:","Successfully completed the action","Installing application '","Install application action completed successfully.")
$filters = [string]::Join('|',$values) 
foreach($file in $logFiles)
{
    $content=$null
    $content= Get-Content $File
    foreach($c in $content)
    {
        if(($c -match $filters) -or ($c -match 'type="3"'))
        {
            $c | Out-File $outputLogFile -Append -Encoding ascii
        }
    }
}
