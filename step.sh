#!/bin/bash
set -ex

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ "${script_input}" == 'Fastlane copy' ]; then
	if [ ! -d "$PWD/fastlane" ]; then
		mkdir $PWD/fastlane
	fi
	cp ${THIS_SCRIPT_DIR}/Fastfile $PWD/fastlane
elif [ "${script_input}" == 'Prep Slack message' ]; then
	ruby "${THIS_SCRIPT_DIR}/prepare_slack.rb"
else 
	gem install hockeyver
	ruby "${THIS_SCRIPT_DIR}/parse_project_settings.rb"
fi

