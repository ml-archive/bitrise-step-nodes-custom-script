#!/bin/bash
set -ex

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "${script_input}" == 'Fastlane copy' ]; then

	# if directory doesn't exist, create it
	if [ ! -d "$PWD/fastlane" ]; then
		mkdir $PWD/fastlane
	fi

	# Try to load fastile for the correct CI version
	if [ -e "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Fastfile" ]; then 
		cp "${THIS_SCRIPT_DIR}/versions/${CI_VERSION}/Fastfile" $PWD/fastlane
	else
		# Ohterwise fallback to default fastfile
		cp ${THIS_SCRIPT_DIR}/versions/Fastfile $PWD/fastlane
	fi

elif [ "${script_input}" == 'Prep Slack message' ]; then
	ruby "${THIS_SCRIPT_DIR}/prepare_slack.rb"
else 
	gem install hockeyver
	ruby "${THIS_SCRIPT_DIR}/parse_project_settings.rb"
fi

