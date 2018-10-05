# Nodes Custom Script

Runs a custom script hosted at our private github


To add this step to your workflow, add this as a step in bitrise.yml: 

`- git::https://github.com/nodes-ios/bitrise-step-nodes-custom-script.git@master:`

Be sure to select the correct input value for the script you want to run:

- `Parse project settings` Runs the `parse_project_settings.rb` script
- `Fastlane copy` Copies the Fastfile into the `/fastlane` directory
-  `Prep Slack message` Runs the `prepare_slack.rb` script