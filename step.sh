#!/bin/bash
set -ex

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Handle CI Version
DEFAULT_CI_VERSION='1.2'
CI_PROJECT_FILE="project.yml"
CI_VERSION_REGEX="ci-version: \"([0-9.]+)\""

if [[ ( -z "${CI_VERSION}" ) && ( `cat project.yml` =~ $CI_VERSION_REGEX ) ]]; then
	# Parse the CI version from the project.yml, unless set by environment
	CI_VERSION=${BASH_REMATCH[1]}
elif [[ -z "${CI_VERSION}" ]]; then
	# Fallback to a default version if not set by environment variable or in project.yml
	CI_VERSION=$DEFAULT_CI_VERSION
fi

echo "Using Nodes CI version: ${CI_VERSION}"

copyFastfile()
{
	# if directory doesn't exist, create it
	if [ ! -d "$PWD/fastlane" ]; then
		mkdir $PWD/fastlane
	fi

	# Try to load fastile for the correct CI version
	if [ -e "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Fastfile" ]; then
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Fastfile" $PWD/fastlane
	else
		# Otherwise fail
		echo "No fastfile found in ci tools version folder ${CI_VERSION}."
		exit 1
	fi
}

if [ "${script_input}" == 'Fastlane copy' ]; then

	copyFastfile

	# Check for plugin capabilities
	if [[ -e "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Pluginfile" &&
					"${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile" &&
	 				"${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile.lock" ]]; then
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Pluginfile" $PWD/fastlane
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile" $PWD
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile.lock" $PWD

		gem install bundler "--force" "--no-document" "-v" "2.0.2"
		bundle install
		bundle exec fastlane -- install_plugins
	fi

elif [ "${script_input}" == 'Prep Slack message' ]; then
	copyFastfile
else
	# Try to load fastile for the correct CI version
	if [ -e "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/parse_project_settings.rb" ]; then
		gem install hockeyver
		ruby "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/parse_project_settings.rb"
	else
		# Otherwise fail
		echo "No fastfile found in ci tools version folder ${CI_VERSION}."
		exit 1
	fi
fi
