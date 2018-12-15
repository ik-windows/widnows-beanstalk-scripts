$stagingDir="C:\staging\";

# Remove C:\staging\ if exists
if ((Test-Path -path $stagingDir))
{
    Remove-Item -Recurse -Force $stagingDir;
}

New-Item $stagingDir -type directory;

& "C:\Program Files\Amazon\ElasticBeanstalk\Tools\AWSBeanstalkCfnZipCheckApp.exe"

exit $LASTEXITCODE

