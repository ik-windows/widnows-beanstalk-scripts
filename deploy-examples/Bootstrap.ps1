$cfn_metadata_cmd = "C:\Program Files\Amazon\cfn-bootstrap\cfn-get-metadata.exe"
$cfn_init_cmd = "C:\Program Files\Amazon\cfn-bootstrap\cfn-init.exe"
$cfn_signal_cmd = "C:\Program Files\Amazon\cfn-bootstrap\cfn-signal.exe"
$logfile = "C:\cfn\log\cfn-init-ebbootstrap"
$env:Path += ";C:\Program Files\Amazon\ElasticBeanstalk\Tools"

$config = @{}
$config.Add("region", $args[0])
$config.Add("stack_name", $args[1])
$config.Add("resource", $args[2])
$config.Add("wait_handle", $args[3])

$url = & $cfn_metadata_cmd --region $config["region"] -s $config["stack_name"] -r $config["resource"] -k  AWS::ElasticBeanstalk::Ext._LaunchS3URL

Function Cfn-Init ($configSet)
{
	& $cfn_init_cmd -s $config["stack_name"] -r $config["resource"] --region $config["region"] -c $configSet >> $logfile 2>&1
}

# Write-Host "$args"

$initFlag = "C:\cfn\eb-system-initialized"
if (Test-path $initFlag)
{
	echo "System initialized"
	Cfn-Init "_OnInstanceReboot"
}
else
{
	echo "Initializing system"
	Cfn-Init "_OnInstanceBoot"
	Get-date > $initFlag
}

$client = new-object System.Net.WebClient
try
{
	$client.DownloadFile($url, [IO.Path]::GetTempFileName())
	echo "Workflow is active. Running Hook-PreInit config" >> $logfile
	Cfn-Init "Hook-PreInit"
}
catch
{
	echo "Workflow is not active. Running _AppInstall config set." >> $logfile
	Cfn-Init "_AppInstall"
}
