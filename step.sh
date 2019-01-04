#!/bin/bash
set -ex

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "${script_input}" == 'Fastlane copy' ]; then

	# if directory doesn't exist, create it
	if [ ! -d "$PWD/fastlane" ]; then
		mkdir $PWD/fastlane
	fi

	# Check if we have ci-version set correctly
	if [ -z "${CI_VERSION}" ]; then
		# not set, fallback to v0.2
		CI_VERSION='0.2'
	fi

		# Try to load fastile for the correct CI version
	if [ -e "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Fastfile" ]; then
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Fastfile" $PWD/fastlane
	else
		# Otherwise fail
		echo "No fastfile found in ci tools version folder ${CI_VERSION}."
		exit 1
	fi

	# Check for plugin capabilities
	if [[ -e "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Pluginfile" &&
					"${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile" &&
	 				"${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile.lock" ]]; then
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Pluginfile" $PWD/fastlane
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile" $PWD
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Gemfile.lock" $PWD

		fastlane install_plugins
	fi

elif [ "${script_input}" == 'Prep Slack message' ]; then
	ruby "${THIS_SCRIPT_DIR}/prepare_slack.rb"
else
	gem install hockeyver
	ruby "${THIS_SCRIPT_DIR}/parse_project_settings.rb"
fi
