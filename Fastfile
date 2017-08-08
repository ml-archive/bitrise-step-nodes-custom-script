#!/usr/bin/env ruby

fastlane_require 'json'
fastlane_require 'pp'

# Customise this file, documentation can be found here:
# https://github.com/fastlane/fastlane/tree/master/fastlane/docs
# All available actions: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Actions.md
# can also be listed using the `fastlane actions` command

# Change the syntax highlighting to Ruby
# All lines starting with a # are ignored when running `fastlane`

# If you want to automatically update fastlane if a new version is available:
# update_fastlane

# This is the minimum version number required.
# Update this, if you use features of a newer version
fastlane_version "2.38.0"
default_platform :ios

DEFAULT_USERNAME="ci@nodes.dk"

$deploy_config = Array.new

platform :ios do

  # ---------------------------------------
  # GENERAL
  # ---------------------------------------

  before_all do |lane, options|

  end

  after_all do |lane|
    puts "After all, checking lane #{lane}"

    if lane == :build
      UI.message "Saving deployment information."
      File.open('deploy_config.json', 'w') { |file| file.write($deploy_config.to_json) }
      puts $deploy_config
    end
  end

  error do |lane, exception|

  end

  # ---------------------------------------
  # LANES
  # ---------------------------------------

  lane :build do |options|
    build_config = JSON.parse ENV['BUILD_CONFIG']
    UI.message "Parsed config: #{pp build_config}"

    build_config.each_pair do |key, target|
      build(target)
    end
  end

  lane :deploy_hockey do |options|    
   
    if ENV['HOCKEY_UPLOAD_FLAG'] == '1' || ENV['TESTFLIGHT_UPLOAD_FLAG'] == '1'
      file = File.read('deploy_config.json')
      $deploy_config = JSON.parse file
      UI.message "Deploy config: #{pp $deploy_config}"
    
      $deploy_config.each do |target|
        hockey(api_token: ENV['HOCKEY_API_TOKEN'],
        ipa: target['hockey_ipa'],
        dsym: target['dsym'],
        notes: target['changelog'],
        notify: "0",
        status: "2")
      UI.message "Target: #{target}"
      end
    else 
      UI.important "Skipping hockey upload due to project.yml settings."
    end
  end 

  lane :deploy_testflight do |options|
    unless ENV['TESTFLIGHT_UPLOAD_FLAG'] == '0'
      file = File.read('deploy_config.json')
      $deploy_config = JSON.parse file
      UI.message "Deploy config: #{pp $deploy_config}"

      $deploy_config.each do |target|
        pilot(ipa: target['testflight_ipa'],
       username: DEFAULT_USERNAME,
       team_name: target['team_name'],
       skip_waiting_for_build_processing: true)
      end
    else 
      UI.important "Skipping testflight upload due to project.yml settings"
    end
  end

  # ---------------------------------------
  # CUSTOM
  # ---------------------------------------

  def build(options)
    UI.message "Building #{options['scheme']} in #{options['configuration']}"

    # Testflight
    # ----------

    provisioning_profile_path = "../#{options['provisioning-profile']}"  

    # Build    
    UI.message "Creating Testflight build"
    ipa_path = gym(scheme: options['scheme'], configuration: options['configuration']) 
    UI.message "Generated IPA at: #{ipa_path}"

    # Hockey
    # ----------

    UI.message "Creating Hockey build"
    hockey_ipa_path = ipa_path.gsub('.ipa', '-hockey.ipa')
    system "cp '#{ipa_path}' '#{hockey_ipa_path}'"

    resign(ipa: hockey_ipa_path,
    signing_identity: "iPhone Distribution: Nodes Aps",
    provisioning_profile: "#{Dir.pwd}/../Signing/enterprise.mobileprovision",
    use_app_entitlements: false)

    UI.message "Hockey IPA at: #{hockey_ipa_path}" 

    $deploy_config << {
      'testflight_ipa' => ipa_path,
      'hockey_ipa' => hockey_ipa_path,
      'dsym' => ipa_path.sub('.ipa', '.app.dSYM.zip'),
      'hockey_app_id' => options['hockey-app-id'],
      'changelog' => ENV['COMMIT_CHANGELOG'],
      'team_name' => get_team_name(provisioning_profile_path)
    }
    UI.success "Successfully built everything."
  end

  def get_team_name(profile)
    # Scrub replaces non-UTF8 characters with ?
    content = File.open(profile).read().scrub("?")

    # Get match for team name
    matches = content.scan /<key>TeamName<\/key>[\s]*<string>([\w\s]*)<\/string>/

    # Return match
    return matches[0].to_s[2...-2] # Removes the brackets and quotes surrounding ["team_name"]
  end

end

# More information about multiple platforms in fastlane: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
# All available actions: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Actions.md

# fastlane reports which actions are used
# No personal data is recorded. Learn more at https://github.com/fastlane/enhancer
