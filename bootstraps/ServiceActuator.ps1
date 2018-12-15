########################################################################################################################
#.SYNOPSIS
#
#   AWS Elastic Beanstalk - Service Actuator
#
#.DESCRIPTION
#
#   Uses option settings to control services
#
#.NOTES
#
#   Services can be quickly added with custom functionality by adding an entry in serviceDefinition with the name
#   of the service and the name of the function which will perform the service-specific functionality.
#
########################################################################################################################
#-----------------------------------------------------------------------------------------------------------------------
# Service Configuration
#-----------------------------------------------------------------------------------------------------------------------
$serviceDefinition      = @{
    XRay = "XRay-Functionality"
}

#-----------------------------------------------------------------------------------------------------------------------
# Localization
#-----------------------------------------------------------------------------------------------------------------------
$_StartingScript        = "Configuring Elastic Beanstalk services..."
$_FailedLoadingConfig   = "Failed to load prerequisite configuration files"
$_FailedWritingMetadata = "Failed to write metadata file"
$_FailedSettingService  = "Failed to set service state"
$_NotAvailable          = "Feature not available"
$_AlreadyDisabled       = "Already disabled"
$_AlreadyEnabled        = "Already enabled"
$_StartingService       = "Starting..."
$_StoppingService       = "Stopping..."
$_Done                  = "...done"

#-----------------------------------------------------------------------------------------------------------------------
# Interface et al.
#-----------------------------------------------------------------------------------------------------------------------
$basePath               = "C:\Program Files\Amazon"
$stackFile              = "C:\cfn\aws-eb-stack.properties"
$containerConfigFile    = "$basePath\ElasticBeanstalk\config\containerconfiguration"
$services               = $serviceDefinition.Keys
$running                = 'Running'


########################################################################################################################
#.SYNOPSIS
# Records program output (insert logging or remotability here)
########################################################################################################################
function Record-State( [string] $state )
{
    # Find root cause
    $ex = $_.Exception
    while( $ex.InnerException -ne $null )
    {
        $ex = $ex.InnerException
    }

    # Format message if exception is present
    $message = $state
    if( $ex )
    {
        $message += "`n`n*** $($ex.Message) ***`n"
    }

    # For now, simply write to console
    Write-Host $message
}

########################################################################################################################
#.SYNOPSIS
# Set service state as specified
########################################################################################################################
function Set-ServiceState( [string] $name, [boolean] $enabled )
{
    try
    {
        # Get service state
        $serviceState = ( Get-Service -Name $name ).Status

        # If service is enabled
        if( $enabled )
        {
            # And is NOT running
            if( $serviceState -ne $running )
            {
                # Enable Service
                Record-State $_StartingService
                Start-Service $name
            }
            else
            {
                Record-State $_AlreadyEnabled
            }
        }
        # If service is disabled
        else
        {
            # And is running
            if( $serviceState -eq $running )
            {
                # Disable Service
                Record-State $_StoppingService
                Stop-Service $name
            }
            else
            {
                Record-State $_AlreadyDisabled
            }
        }
    }
    catch
    {
        Record-State $_FailedSettingService
    }
}


########################################################################################################################
#
# Service-specific Functionality
#
########################################################################################################################

########################################################################################################################
#.SYNOPSIS
#       Writes environment.conf and enables or disables the service
########################################################################################################################
function XRay-Functionality()
{
    # Locals
    $serviceName            = "aws-xray"
    $servicePath            = "$basePath\XRay"
    $serviceConfigFile      = "$servicePath\environment.conf"

    # TODO: Get proper values
    # File Contents
    $xrayMeta = @{
        deployment_id = "1"
        version_label = "v0"
        environment_name = $stack["environment_name"]
        environment_id = $stack["environment_id"]
    }

    try
    {
        # Ensure path exists
        if( !( Test-Path -path $servicePath ) )
        {
            New-Item $servicePath -type Directory
        }

        # Write config to file as JSON
        Set-Content -Force -Path $serviceConfigFile -Value ( $xrayMeta | ConvertTo-Json )
    }
    catch
    {
        # Failure to write metadata is not terminal
        Record-State $_FailedWritingMetadata
    }

    # Attempt to read new value from config
    $enabled = $false
    try
    {
        # Read desired state from container config
        $enabled = [System.Convert]::ToBoolean($config.container.xray_enabled)
    }
    catch
    {
        Record-State $_NotAvailable
    }

    # Finally, set service state
    Set-ServiceState $serviceName $enabled
}


########################################################################################################################
#
# Start of script
#
########################################################################################################################
Record-State $_StartingScript

#-----------------------------------------------------------------------------------------------------------------------
# Read configuration files
#-----------------------------------------------------------------------------------------------------------------------
try
{
    # Container Config
    $config = Get-Content -Raw -Path $containerConfigFile | ConvertFrom-Json

    # Stack Properties
    $stack = Get-Content -Raw -Path $stackFile | ConvertFrom-StringData
}
catch
{
    Record-State $_FailedLoadingConfig
    exit
}

#-----------------------------------------------------------------------------------------------------------------------
# Install Services
#-----------------------------------------------------------------------------------------------------------------------
$services | % { Record-State "[$_]" ; & $serviceDefinition[$_] }

#-----------------------------------------------------------------------------------------------------------------------
# The End / El Fin / Das Ende                                                           Au Revoir / Das Vidania / Ciao #
#-----------------------------------------------------------------------------------------------------------------------
Record-State $_Done
