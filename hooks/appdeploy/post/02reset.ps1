$env:Path=$env:Path+";C:\Program Files\Amazon\ElasticBeanstalk\Tools\multiapp";

$previousStagingDir="C:\staging-previous\";
$logsDir="C:\Program Files\Amazon\ElasticBeanstalk\logs";
$manifestName="aws-windows-deployment-manifest.json";

$exitCode = 0;
$maxRetries = 4;
$sleepBetweenFailures = 1;

if (Test-Path ($previousStagingDir+$manifestName))
{
    $newmanifest=$previousStagingDir+$manifestName;

    aws.deploytools.exe -restart -manifest="$newmanifest" -logdirectory="$logsDir";
    $exitCode = $lastExitCode;
}
else
{
    for ($i=0; $i -le $maxRetries; $i++)
    {
        iisreset
        $exitCode = $lastExitCode;
        if ($exitCode -eq 0)
        {
            break;
        }
        Write-Error -Message "IISReset failed.";
        $sleepBetweenFailures = ($sleepBetweenFailures * 2);
        Write-Host "Waiting for $sleepBetweenFailures seconds before retrying...";
        Start-Sleep -s $sleepBetweenFailures;
        Write-Host "Retrying...";
    }
    Write-Error -Message "IISReset failed. Stopped script.";
}
exit $exitCode;