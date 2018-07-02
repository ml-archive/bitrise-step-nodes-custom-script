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
DEFAULT_SLACK_WEBHOOK="https://hooks.slack.com/services/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"

$deploy_config = Array.new
$notify_config = Array.new

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
    # Send error notification
    addErrorMessage("Build failed in lane: #{lane} with message: \n #{exception}")
  end

  # ---------------------------------------
  # LANES
  # ---------------------------------------

  lane :build do |options| 
    build_config = JSON.parse ENV['BUILD_CONFIG']
    UI.message "Parsed config: #{pp build_config}" 
    build_config.each_pair do |target, target_config|
      build(target, target_config)
    end  
    save_notify_info
  end

  lane :deploy_hockey do |options|    
    
    if ENV['HOCKEY_UPLOAD_FLAG'] == '1' || ENV['TESTFLIGHT_UPLOAD_FLAG'] == '1'
      
      $notify_config.clear
      file = File.read('deploy_config.json')
      $deploy_config = JSON.parse file     
  
      $deploy_config.each do |target|
        UI.message "Starting hockey upload target #{target}"
        hockey(
          api_token: ENV['HOCKEY_API_TOKEN'],
          ipa: target['hockey_ipa'],
          dsym: target['dsym'],
          notes: target['changelog'],
          notify: "0",
          public_identifier: target['hockey_app_id']   
        )
        info = lane_context[Actions::SharedValues::HOCKEY_BUILD_INFORMATION]       
        $notify_config << {
          'scheme' => target['scheme'],
          'configuration' => target['configuration'],
          'xcode_version' => target['xcode_version'],
          'xcode_build' => target['xcode_build'],
          'hockey_link' => info['config_url']
        }
      end     
      save_notify_info
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
        # This checks for team_id and uses that if available
        team_name = target['team_name']
        team_id = target['team_id']
        unless team_id.nil?
          team_name = nil
        end
        team_name =
        pilot(
          ipa: target['testflight_ipa'],
          username: target['upload_account'] || DEFAULT_USERNAME,
          team_id: team_id,
          team_name: team_name,
          skip_waiting_for_build_processing: true,
          itc_provider: target['itc_provider']
        )     
      end      
    else 
      UI.important "Skipping testflight upload due to project.yml settings"
    end
  end

  lane :notify_slack do |options| 
    ENV["SLACK_URL"] = DEFAULT_SLACK_WEBHOOK


    error = File.read('../error_message') if File.file?('../error_message')

    unless error
      UI.message "Success!"
      config = JSON.parse ENV["NOTIFY_CONFIG"]
      # Debug data
      #config = JSON.parse '[{"scheme":"FirstTarget","configuration":"Test (Live)","xcode_version":"1.0","xcode_build":"125","hockey_link":"https://rink.hockeyapp.net/manage/apps/562313/app_versions/88"}]'
   
      config.each do |target|          
        hockeylink = target['hockey_link'] || "Hockey build disabled"   
        if ENV['TESTFLIGHT_UPLOAD_FLAG'] == '1'
          testflightmessage = "New build processing on Testflight"
        else 
          testflightmessage = "Testflight build disabled"
        end

        slack(
          message: "Build succeeded for #{target['scheme']} #{target['configuration']} \n Version #{target["xcode_version"]} (#{target["xcode_build"]})",
          channel: ENV["SLACK_CHANNEL"],        
          success: true,
          username: "iOS CI",
          payload: {
        	 "Hockey" => hockeylink,
        	 "Testflight" => testflightmessage
          },
          default_payloads: [:git_branch, :git_author]        
        )
      end
    else 
      UI.message "Error"
      slack(
        message: error,
        channel: "ios-ci",
        success: false,        
        username: "iOS CI",
        default_payloads: [:git_branch, :git_author]
      )
      File.delete('../error_message')
    end         
  end 

  # ---------------------------------------
  # CUSTOM
  # ---------------------------------------

  def build(target, options)
    UI.message "Building #{target} with scheme #{options['scheme']} in #{options['configuration']} configuration."

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
   
    # Install certificates and profiles for extensions
    extensions_ids = options["extensions_bundle_ids"] ||= Array.new
    unless extensions_ids.empty?
      extensions_ids.each do |extension_id|
        match(
          git_url: DEFAULT_MATCH_REPO,
          git_branch: match_branch,
          type: export_method_match,
          app_identifier: extension_id,       
          readonly: true
        )   
      end
    end

    path_env_var = "sigh_#{bundle_id}_#{export_method_match}_profile-path"
    team_env_var = "sigh_#{bundle_id}_#{export_method_match}_team-id"    
    provisioning_profile_path = ENV["#{path_env_var}"]
    team_id = ENV["#{team_env_var}"] 

    UI.message "Switching to manual code signing"
    disable_automatic_code_signing(
      path: options['xcodeproj'],
      targets: target,
      team_id: team_id
    )     

    UI.message "Setting provisioning profile"
    update_project_provisioning(
      xcodeproj: options['xcodeproj'],
      target_filter: target,
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
      'team_name' => get_team_name(provisioning_profile_path),
      'team_id' => options["team_id"],
      'itc_provider' => options["itc_provider"],
      'scheme' => options['scheme'],
      'configuration' => options['configuration'],
      'xcode_version' => options['xcode_version'],
      'xcode_build' => options['xcode_build'],
      'upload_account' => options['testflight-upload-account']      
    }

    $notify_config << {  
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
  def save_notify_info() 
    system "bitrise envman add --key NOTIFY_CONFIG --value '#{$notify_config.to_json}' --no-expand"
  end

  def addErrorMessage(message)  
    File.open('../error_message', 'w') { |file| file.write(message) }
  end

end

# More information about multiple platforms in fastlane: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
# All available actions: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Actions.md

# fastlane reports which actions are used
# No personal data is recorded. Learn more at https://github.com/fastlane/enhancer
