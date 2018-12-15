#==============================================================================
# Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#       https://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions
# and limitations under the License.
#==============================================================================

$container_config = "C:\Program Files\Amazon\ElasticBeanstalk\config\containerconfiguration"
$ssm_cwl_config = "C:\Program Files\Amazon\SSM\Plugins\awsCloudWatch\AWS.EC2.Windows.CloudWatch.json"
$eb_cwl_config = "C:\Program Files\Amazon\ElasticBeanstalk\Tools\logstream\AWS.EC2.Windows.CloudWatch.json"
$custom_config_failure_msg = "[ERROR] Custom SSM awsCloudWatch plugin configuration files (AWS.EC2.Windows.CloudWatch.json) detected, failing deployment."
$custom_config_warning_msg = "[WARN] Custom SSM awsCloudWatch plugin configuration files (AWS.EC2.Windows.CloudWatch.json) detected, keeping plugin running."
$keep_on_msg = "[INFO] SSM CloudWatch already running."
$turn_on_msg = "[INFO] SSM CloudWatch plugin turned on with Elastic Beanstalk config."
$turn_off_msg = "[INFO] SSM CloudWatch plugin turned off."

# Check if it is safe to take control over SSM CWL plugin
function Safe-To-Configure {
    # If there is an existing SSM CWL plugin config file and it is NOT the eb maintained one,
    if ((Test-Path $ssm_cwl_config) -And (Compare-Object (Get-Content $ssm_cwl_config) (Get-Content $eb_cwl_config))) {
        return $false
    }
    return $true
}

function Turn-On-CWL-Plugin {
    if (Safe-To-Configure) {
        if (-Not (Test-Path $ssm_cwl_config)) {
            cp $eb_cwl_config $ssm_cwl_config
            Restart-Service AmazonSSMAgent
            Write-Host $turn_on_msg
        } else {
            # Agent is running with eb managed config, skip restart agent
            Write-Host $keep_on_msg
        }
    } else {
        Write-Host ($custom_config_failure_msg)
        exit -1
    }
}

function Turn-Off-CWL-Plugin {
    if (Safe-To-Configure) {
        if (Test-Path $ssm_cwl_config) {
            Remove-Item -Path $ssm_cwl_config
        }
        Restart-Service AmazonSSMAgent
        Write-Host $turn_off_msg
    } else {
        Write-Host $custom_config_warning_msg
    }
}



try {
    $container_config = Get-Content -Raw -Path $container_config | ConvertFrom-Json
} catch {
    Write-Host ("Unable to read containerconfig file")
    exit -1
}

if (!$container_config) {
    Write-Host ("container-config length is 0")
    exit -1
}

$logstream_enabled = $container_config.optionsettings."aws:elasticbeanstalk:cloudwatch:logs"."StreamLogs"

if ($logstream_enabled -eq "true") {
    Turn-On-CWL-Plugin
} else {
    Turn-Off-CWL-Plugin
}
