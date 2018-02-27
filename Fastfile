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
DEFAULT_MATCH_REPO="git@github.com:nodes-projects/internal-certificates-ios.git"
DEFAULT_ENTERPRISE_BRANCH="nodes-enterprise"
DEFAULT_ENTERPRISE_TEAM="HW27H6H98R"

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
     save_deploy_info

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
     
      # This is messy because we need to mutate the deploy_config by adding the new
      # hockey URL and I dont know how to do that in Ruby
      old_deploy_config = $deploy_config.clone
      $deploy_config.clear  
      old_deploy_config.each do |target|
        UI.message "Starting hockey upload target #{target}"
        hockey(api_token: ENV['HOCKEY_API_TOKEN'],
        ipa: target['hockey_ipa'],
        dsym: target['dsym'],
        notes: target['changelog'],
        notify: "0",
        status: "2")
      info = lane_context[Actions::SharedValues::HOCKEY_BUILD_INFORMATION]    
      target['hockey_link'] = info['config_url']
      $deploy_config << target
      end     
      save_deploy_info
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
        skip_waiting_for_build_processing: true,
        itc_provider: target['itc_provider'])     
      end      
    else 
      UI.important "Skipping testflight upload due to project.yml settings"
    end
  end

  lane :notify_slack do |options| 
    UI.message "Hello world"

  end 

  # ---------------------------------------
  # CUSTOM
  # ---------------------------------------

  def build(options)
    UI.message "Building #{options['scheme']} in #{options['configuration']}"

    # Testflight
    # ----------


    bundle_id = options['bundle_id']
    archive_path = "#{Dir.pwd}/../archive.xcarchive"
    export_method = ENV['EXPORT_METHOD'] 
    export_method_match = export_method.gsub('-', '')

     # Certificates and profiles
    UI.message "Installing certificate and profiles"

    match_branch = options["match-git-branch"]    
    match(
      git_url: DEFAULT_MATCH_REPO,
      git_branch: match_branch,
      type: export_method_match,
      app_identifier: bundle_id,       
      readonly: true
    )
    
   
    path_env_var = "sigh_#{bundle_id}_#{export_method_match}_profile-path"
    team_env_var = "sigh_#{bundle_id}_#{export_method_match}_team-id"    
    provisioning_profile_path = ENV["#{path_env_var}"]
    team_id = ENV["#{team_env_var}"] 

    UI.message "Switching to manual code signing"
    disable_automatic_code_signing(
      path: options['xcodeproj'],
      targets: options['scheme'],
      team_id: team_id
    )     

    UI.message "Setting provisioning profile"
    update_project_provisioning(
      xcodeproj: options['xcodeproj'],
      target_filter: options['scheme'],
      profile: provisioning_profile_path
    )

    # Build    
    UI.message "Creating Testflight build"    

    # Fastlane wont let you pass both a workspace and project
    workspace = options['workspace']
    project = options['xcodeproj']
    unless workspace.nil? 
      project = nil
      UI.message "Installing Cocoapods"    
      cocoapods # I mean this is why you're using a workspace, right?
    end

    ipa_path = gym(
      workspace: workspace,
      project: project,
      scheme: options['scheme'], 
      configuration: options['configuration'],    
      export_method: export_method,
      archive_path: archive_path,
      export_team_id: team_id,
      codesigning_identity: "iPhone Distribution"
    )       
    UI.message "Generated IPA at: #{ipa_path}"

    UI.message "Re-exporting archive without bitcode"    
    second_path = gym(
      workspace: workspace,
      project: project,
      scheme: options['scheme'],
      output_name: "#{options['scheme']}-hockey", 
      configuration: options['configuration'],
      include_bitcode: false,
      skip_build_archive: true,
      archive_path: archive_path
    ) 
    UI.message "Generated non-bitcode IPA at: #{second_path}"

    # Hockey
    # ----------
    UI.message "Installing certificate and profiles"
        match(
          git_url: DEFAULT_MATCH_REPO,
          git_branch: DEFAULT_ENTERPRISE_BRANCH,
          type: "enterprise",
          app_identifier: "*",         
          team_id: DEFAULT_ENTERPRISE_TEAM, 
          readonly: true
        )

    UI.message "Creating Hockey build"
    
    resign(
      ipa: second_path,
      signing_identity: "iPhone Distribution: Nodes Aps",
      provisioning_profile: ENV['sigh_*_enterprise_profile-path'],
      use_app_entitlements: false,
      verbose: true
    )

    UI.message "Hockey IPA at: #{second_path}"   

    # If for some reason the get_team_name doesnt work, you can manually specify it
    team_name = options["team_name"]
    if team_name.nil?
      team_name = get_team_name(provisioning_profile_path)
    end

    $deploy_config << {
      'testflight_ipa' => ipa_path,
      'hockey_ipa' => second_path,
      'dsym' => ipa_path.sub('.ipa', '.app.dSYM.zip'),
      'hockey_app_id' => options['hockey-app-id'],
      'changelog' => ENV['COMMIT_CHANGELOG'],
      'team_name' => team_name,
      'itc_provider' => options["itc_provider"],
      'scheme' => options['scheme'],
      'configuration' => options['configuration'],
      'xcode_version' => options['xcode_version'],
      'xcode_build' => options['xcode_build']
    }
    UI.success "Successfully built everything."
  end

  def get_team_name(profile)
    # Scrub replaces non-UTF8 characters with ?
    content = File.open(profile).read().scrub("?")

    # Get match for team name
    matches = content.scan /<key>TeamName<\/key>[\s]*<string>(...*)<\/string>/
   
    # Return match
    return matches[0].to_s[2...-2] # Removes the brackets and quotes surrounding ["team_name"]
  end

  def save_deploy_info()
      UI.message "Saving deployment information."
      File.open('deploy_config.json', 'w') { |file| file.write($deploy_config.to_json) }
      puts $deploy_config
      system "bitrise envman add --key DEPLOY_CONFIG --value '#{$deploy_config.to_json}' --no-expand"
  end 

end

# More information about multiple platforms in fastlane: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
# All available actions: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Actions.md

# fastlane reports which actions are used
# No personal data is recorded. Learn more at https://github.com/fastlane/enhancer
