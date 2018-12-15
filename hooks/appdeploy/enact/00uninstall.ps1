$env:Path = $env:Path + ";C:\Program Files\Amazon\ElasticBeanstalk\Tools\multiapp";

$previousStagingDir="C:\staging-previous\";
$logsDir="C:\Program Files\Amazon\ElasticBeanstalk\logs";
$manifestName="aws-windows-deployment-manifest.json";

if (Test-Path $previousStagingDir)
{
    $oldmanifest=$previousStagingDir+$manifestName;

    aws.deploytools.exe -uninstall -manifest="$oldmanifest" -logdirectory="$logsDir";

    Remove-Item -Path $previousStagingDir -Recurse;
}

