$env:Path=$env:Path+";C:\Program Files\IIS\Microsoft Web Deploy V3\;C:\Program Files\Amazon\ElasticBeanstalk\Tools;C:\Program Files\Amazon\ElasticBeanstalk\Tools\multiapp";

$stagingDir="C:\staging\";
$previousStagingDir="C:\staging-previous\";
$logsDir="C:\Program Files\Amazon\ElasticBeanstalk\logs";
$manifestName="aws-windows-deployment-manifest.json";

$exitCode = 0;

if (Test-Path ($stagingDir+$manifestName))
{
    $newmanifest=$stagingDir+$manifestName;
    
    Get-ChildItem -Recurse -Include .ebextensions $stagingDir | Remove-Item -Recurse -Force;

    aws.deploytools.exe -install -manifest="$newmanifest" -logdirectory="$logsDir";

    $exitCode = $lastExitCode;

    New-Item -ItemType Directory -Path $previousStagingDir;
    (Get-ChildItem $stagingDir) | foreach { Copy-Item ($stagingDir + $_) -Destination $previousStagingDir -Recurse -Container}
}
else {
    $sourceBundleFinal="C:\cfn\ebdata\source_bundle_final.zip";
    $parameters=$stagingDir+"parameters.xml";
    
    Get-ChildItem -Recurse -Include .ebextensions $stagingDir | Remove-Item -Recurse -Force;

    $output = & Msdeploy.exe -verb:sync -declareParamFile:$parameters -dest:package=$sourceBundleFinal -source:archiveDir=$stagingDir;

    Deploy.exe -c "c:\Program Files\Amazon\ElasticBeanstalk\config\containerconfiguration" -p $sourceBundleFinal;

    $exitCode = $lastExitCode;
}

exit $exitCode;

