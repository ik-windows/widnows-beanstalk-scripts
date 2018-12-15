$env:Path=$env:Path+";C:\Program Files\Amazon\ElasticBeanstalk\Tools;"

$manifest="aws-windows-deployment-manifest.json";
$sourceBundle="C:\cfn\ebdata\source_bundle.zip";
$sourceBundleFinal="C:\cfn\ebdata\source_bundle_final.zip";
Test-Path -Path $sourceBundle -Filter $manifest;

[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')

if (([IO.Compression.ZipFile]::OpenRead($sourceBundle).Entries.FullName) -notcontains $manifest  )
{
    Write-Output "No manifest found in $sourceBundle, deploying configuration"
    Deploy.exe -c "c:\Program Files\Amazon\ElasticBeanstalk\config\containerconfiguration" -p $sourceBundleFinal;
} else {
    Write-Output "Manifest found in $sourceBundle, skipping config deploy"
}

