$stack_props_file="C:\cfn\aws-eb-stack.properties"
$logfile = "C:\cfn\log\eb-version-deployment.log"
$tmp_version_manifest_file = "C:\cfn\version_manifest"
$version_download_location = "C:\cfn\ebdata\source_bundle.zip"

Function Err_Exit($Exception)
{
	$exception_message = $Exception.Message
	LogWrite $exception_message

	echo $exception_message
	exit 1
}

Function LogWrite($message)
{
	$formatted_message_log_string = [string]::Format("{0} $message", (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
	Add-content $logfile -value $formatted_message_log_string
}

Function Download_Source_Bundle($version_manifest_json_tree, $env_id, $bucket_name, $region, $java_script_serializer) {

	$runtime_sources_tree = $version_manifest_json_tree['RuntimeSources']
	$version_s3_key_name = $null

	foreach ($all_app_versions_info in $runtime_sources_tree) {
		$app_name_keys = $all_app_versions_info.Keys
		if($app_name_keys.count -eq 0) {
			break
		}

		foreach($app_name in $app_name_keys) {
			$app_versions_info = $all_app_versions_info[$app_name]
			$version_label_keys = $app_versions_info.Keys
			if($version_label_keys.count -eq 0){
				continue
			}
			foreach($version_label in $version_label_keys) {
					$version_s3_key_name = [string]::Format("resources/environments/{0}/_runtime/_versions/{1}/{2}",$env_id, $app_name, $version_label)
					Read-S3Object -BucketName $bucket_name -Key $version_s3_key_name -File $version_download_location
					LogWrite ([string]::Format("Downloaded version label {0} from s3 key {1}", $version_label, $version_s3_key_name))
					return $true
			}
		}
	}

	if($version_s3_key_name -eq $null){
		$app_source_config_location = "C:\Program Files\Amazon\ElasticBeanstalk\config\appsourceurl"

		$app_source_file_data = Get-Content $app_source_config_location
		$app_source_json_data = $java_script_serializer.DeserializeObject($app_source_file_data)
		$app_source_url = $app_source_json_data['url']

		$webClient = New-Object System.Net.WebClient

		if((Test-Path "C:\cfn\ebdata") -eq 0) {
			New-Item -ItemType directory -Path "C:\cfn\ebdata"
		}

		$webClient.DownloadFile($app_source_url,$version_download_location)

		LogWrite ([string]::Format("Downloaded sample application to the environment."))
	}

	return $true
}

Function Download_Source_Bundle_Retry($version_manifest_json_tree, $env_id, $bucket_name, $region, $java_script_serializer) {

	$counter = 0
	$success = $false
	do{
		try{
			$success = Download_Source_Bundle $version_manifest_json_tree $env_id $bucket_name $region $java_script_serializer
		} catch [Exception] {
			$counter = $counter + 1;
			if ($counter -gt 20) {
				LogWrite ([string]::Format("Reached the max limit of 20 tries. Giving up and returning last exception received: {0}", $_.Exception.Message))
				LogWrite ([string]::Format("Exception in downloading the source bundle from bucket {0} ", $bucket_name))
                Err_Exit($_.Exception)
            } else {
            	LogWrite ([string]::Format("Encountered Exception trying to download source bundle: {0}", $_.Exception.Message))
            	LogWrite ([string]::Format("Sleeping 5 seconds before retrying"))
                Start-Sleep -s 5;
            }
		}
	} while(!$success)
}

Function Read_Manifest_Download_Source_Bundle($bucket_name, $region, $env_id) {

	Add-Type -AssemblyName System.Web.Extensions
	$java_script_serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
	$version_manifest_file_contents = Get-Content $tmp_version_manifest_file
	$version_manifest_json_tree = $java_script_serializer.DeserializeObject($version_manifest_file_contents)

	Download_Source_Bundle_Retry $version_manifest_json_tree $env_id $bucket_name $region $java_script_serializer

}

Function Download_Version_Manifest_File_Retry($bucket_name, $latest_version_manifest_file_s3_key_name, $region) {
	Read-S3Object -BucketName $bucket_name -Key $latest_version_manifest_file_s3_key_name -File $tmp_version_manifest_file -Region $region
	LogWrite "Downloaded the version info file to C:\cfn\version_manifest"
}

Function Download_Version_Manifest_File($bucket_name, $latest_version_manifest_file_s3_key_name, $region)
{
	$counter = 0
	$success = $false
	do{
		try{
			$success = Download_Version_Manifest_File_Retry $bucket_name $latest_version_manifest_file_s3_key_name $region
		} catch [Exception] {
			$counter = $counter + 1;
			if ($counter -gt 20) {
				LogWrite ([string]::Format("Reached the max limit of 20 tries. Giving up and returning last exception received: {0}", $_.Exception.Message))
				LogWrite ([string]::Format("Exception in downloading the version manifest file from bucket {0} and key {1}", $bucket_name, $latest_version_manifest_file_s3_key_name))
                Err_Exit($_.Exception)
            } else {
            	LogWrite ([string]::Format("Encountered Exception trying to download manifest file: {0}", $_.Exception.Message))
            	LogWrite ([string]::Format("Sleeping 5 seconds before retrying"))
                Start-Sleep -s 5;
            }
		}
	} while(!$success)
}

Function Get_Latest_Version_Manifest_File_S3_Key_Retry($bucket_name, $version_manifest_dir_prefix, $region)
{
	$key = $null
    $timestamp = [datetime]::MinValue

    for($count=0; $count -lt 3; $count++) {
    	$s3keys = Get-S3Object -BucketName $bucket_name -KeyPrefix $version_manifest_dir_prefix -Region $region
    	foreach ($s3key in $s3keys){
        	if(([datetime]::Parse($s3key.LastModified)) -gt ([datetime]::Parse($timestamp)) -and ($s3key.Key.Contains("manifest")) -and (-not ($s3key.Key.EndsWith("/")))) {
        		$timestamp = $s3key.LastModified
            	$key = $s3key
        	}
    	}
    }

    if($key -ne $null){
        LogWrite ([string]::Format("Found the latest version manifest file {0} from bucket {1} and prefix {2}", $key.Key, $bucket_name, $version_manifest_dir_prefix))
    } else {
        # Throw an exception as we want to retry
    	$message = ([string]::Format("No manifest file Key found. Cannot find latest version manifest file for prefix {0}", $version_manifest_dir_prefix))
        throw $message
    }

    return $key
}

Function Get_Latest_Version_Manifest_File_S3_Key($bucket_name, $version_manifest_dir_prefix, $region)
{
	$counter = 0
	$success = $false
	$key = $null
	do{
		try{
			$key = Get_Latest_Version_Manifest_File_S3_Key_Retry $bucket_name $version_manifest_dir_prefix $region
			$success = $true
		} catch [Exception] {
			$counter = $counter + 1;
			if ($counter -gt 20) {
				LogWrite ([string]::Format("Reached the max limit of 20 tries. Giving up and returning last exception received: {0}", $_.Exception.Message))
				LogWrite ([string]::Format("Exception in getting the location of latest version manifest file from bucket {0} and prefix {1}", $bucket_name, $version_manifest_dir_prefix))
                Err_Exit($_.Exception)
            } else {
            	LogWrite ([string]::Format("Encountered Exception trying to get the location of latest manifest file: {0}", $_.Exception.Message))
            	LogWrite ([string]::Format("Sleeping 5 seconds before retrying"))
                Start-Sleep -s 5;
            }
		}
	} while(!$success)

	return $key
}

Function Read_Stack_Properties_File()
{
	$stack_props = @{}
	foreach ($service in Get-Content $stack_props_file)
	{
		$name,$val=$service.split("=")
		$stack_props[$name]=$val
	}

	return $stack_props
}

# Get the customer service bucket, region and environment reference id from stack properties file
$stack_props = Read_Stack_Properties_File
$bucket_name = $stack_props['environment_bucket']
$region = $stack_props['region']
$env_id = $stack_props['environment_id']

# create the version manifest file prefix
$version_manifest_dir_prefix = [string]::Format("resources/environments/{0}/_runtime/versions/", $env_id)

# Get the manifest file, first check in the command data otherwise get the latest file
$latest_version_manifest_file_s3_key_name = $null
$manifest_file_name = $env:EB_COMMAND_DATA
if([string]::IsNullOrEmpty($manifest_file_name)) {
	$latest_version_manifest_file_s3_key = Get_Latest_Version_Manifest_File_S3_Key $bucket_name $version_manifest_dir_prefix $region
	$latest_version_manifest_file_s3_key_name = $latest_version_manifest_file_s3_key.Key
} else {
	$latest_version_manifest_file_s3_key_name = [string]::Format("{0}{1}", $version_manifest_dir_prefix, $manifest_file_name)
	LogWrite ([string]::Format("Version manifest file name already known. The latest version manifest file key is {0}", $latest_version_manifest_file_s3_key_name))
}

# Read manifest file
# role should have permissions to get the manifest file object
Download_Version_Manifest_File $bucket_name $latest_version_manifest_file_s3_key_name $region

# Download the source bundle to correct location
# role should have permissions to download the source bundle
Read_Manifest_Download_Source_Bundle $bucket_name $region $env_id

# clean up the temporary manifest file
If (Test-Path $tmp_version_manifest_file){
	Remove-Item $tmp_version_manifest_file
}