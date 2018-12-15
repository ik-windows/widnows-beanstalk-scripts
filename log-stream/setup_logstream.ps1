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

$logstream_dir = "C:\Program Files\Amazon\ElasticBeanstalk\Tools\logstream"
$eb_stack_properties = "C:\cfn\aws-eb-stack.properties"

# Get environment name and instance region
$environment_name = cat $eb_stack_properties | where {$_ -match "environment_name="} | %{$_ -replace "environment_name=", ""}
$region = cat $eb_stack_properties | where {$_ -match "region="} | %{$_ -replace "region=", ""}

# Generate Beanstalk maintained SSM awsCloudWatch plugin config file
(Get-Content "$logstream_dir\AWS.EC2.Windows.CloudWatch.json.template").replace('%%REGION%%', $region).replace("%%ENVIRONMENT_NAME%%", $environment_name) | Set-Content "$logstream_dir\AWS.EC2.Windows.CloudWatch.json"
