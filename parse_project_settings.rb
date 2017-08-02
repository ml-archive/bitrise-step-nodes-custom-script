#!/usr/bin/env ruby
require 'yaml'
require 'xcodeproj'
require 'fileutils'
require 'pp'
require 'plist'
require 'hockeyver'
require 'json'

# -------
# Constants
# -------

PROJECT_FILE_NAME='project.yml'
TARGET_FILE='build_config.json'
DEBUG_MODE=false
VERBOSE=false

# -------
# Helpers
# -------

def colorize(text, color_code)
  "\e[#{color_code}m#{text}\e[0m"
end
def red(text); colorize(text, 31); end
def green(text); colorize(text, 32); end
def yellow(text); colorize(text, 33); end
def bold(text); "\e[1m#{text}\e[22m" end

class Version < Array
  def initialize s
    super(s.split('.').map { |e| e.to_i })
  end
  def < x
    (self <=> x) < 0
  end
  def > x
    (self <=> x) > 0
  end
  def == x
    (self <=> x) == 0
  end
  def >= x
    (self <=> x) >= 0
  end
end

# -------
# Main
# -------

# Load YAML
puts bold "Loading settings from #{PROJECT_FILE_NAME}"
raise red "|- Couldn't find project.yml file" unless File.exist?(PROJECT_FILE_NAME)
project_settings = YAML.load_file(PROJECT_FILE_NAME)

# Load some settings
xcodeproj_path = project_settings['xcodeproj']
configuration = project_settings["configuration"]
PROJECT_ROOT_DIR = File.dirname(xcodeproj_path) + "/"

# Load Xcode project
raise red "|- Couldn't find Xcode project at: #{xcodeproj_path}" unless File.exist?(xcodeproj_path)
xcode_project = Xcodeproj::Project.open xcodeproj_path

# Validate configuration
avialable_configurations = xcode_project.build_configurations.map { |x|
  puts "|- #{x.name}" if VERBOSE
  x.name
}
raise red "|- Can't find configuration #{configuration}" unless avialable_configurations.include? configuration

# Notify
puts green "|- Settings loaded succesfully with configuration: #{project_settings["configuration"]}."

# Load upload settings 
hockey_upload = project_settings['hockey-upload'] ? 1 : 0
testflight_upload = project_settings['testflight-upload'] ? 1 : 0
puts ""
puts bold "Checking upload settings"
if hockey_upload == 1
  puts green "|- Will upload to hockey"
else
  puts yellow "|- Skipping hockey upload"
end
if testflight_upload == 1
  puts green "|- Will upload to testflight"
else 
  puts yellow "|- Skipping testflight upload"
end 


# Get available targets
validated_targets = Hash.new

# Validate targets
puts ""
puts bold "Validating target settings"
project_settings["targets"].each_pair { |key, val|
    xcode_target = xcode_project.targets.select { |tar| tar.name == key }.first

    # Check for target existence
    if xcode_target.nil?
      puts yellow "|- Skipping target #{key}, as Xcode doesn't contain corresponding target."
      next
    end

    # Check if enabled
    unless val["enabled"]
      puts yellow "|- Skipping target #{key}, because it is disabled."
      next
    end

    # Validate scheme
    unless Xcodeproj::Project.schemes(xcodeproj_path).include? val["scheme"]
      puts yellow """|- Skipping target #{key}, because the specified scheme can't be found.
      Did you set it the scheme as shared?"""
      next
    end

    puts green "|- Found valid target #{key}."
    validated_targets[key] = { "settings" => val, "target" => xcode_target }
}

# Make sure we have something to build
unless validated_targets.count > 0
  raise red "|- No valid targets to build, build failed."
end

puts ""
puts bold "Starting Hockey versions verification"

valid = true

unless DEBUG_MODE
  # Get version and build numbers
  validated_targets.each_pair { |key, val|

    # Find the correct configuration
    configs = val["target"].build_configurations
    index = configs.index { |x| x.name == configuration }

    # Get info plist
    info_plist = configs[index].build_settings["INFOPLIST_FILE"]
    info_plist_path = PROJECT_ROOT_DIR + info_plist

    plist = Plist.parse_xml info_plist_path
    xcode_version = plist["CFBundleShortVersionString"]
    xcode_build = plist["CFBundleVersion"].to_i

    puts "|- Verifying '#{key}' with version #{xcode_version} (#{xcode_build})."

    # Get numbers from hockey
    hockey_app_id = val["settings"]["hockey-app-id"]
    buildnumber = HockeyVer.parse_hockey_version hockey_app_id, ENV["HOCKEY_API_TOKEN"]

    hockey_version = buildnumber["version"]
    hockey_build = buildnumber["build"].to_i

    # Compare, make sure that build is always higher and version is at least higher or equal
    unless (Version.new(xcode_version) >= Version.new(hockey_version)) && (xcode_build > hockey_build)
      valid = false
      puts yellow """|- #{key}: Xcode version #{xcode_version} (#{xcode_build}) is lower or equal than the one on Hockey #{hockey_version} (#{hockey_build})."""
    end
  }
end

# Check if we can continue
raise red "Can't continue with build, as version and build numbers must be higher than the ones on Hockey." unless valid

# All done
puts green "|- All version and build numbers are correct."

puts ""
puts bold "Creating information required for build"

build_config = Hash.new
certificates = ""
profiles = ""
passwords = ""

validated_targets.each_pair { |key, val|
  content = val['settings']

  # Pass platform, xcodeproj
  content['xcodeproj'] = xcode_project.path.to_path
  content['platform'] = val['target'].platform_name
  content['configuration'] = configuration
  content['bundle_id'] = val['target'].build_settings(configuration)['PRODUCT_BUNDLE_IDENTIFIER']
 
  # Extract build number 
  info_plist = val['target'].build_settings(configuration)["INFOPLIST_FILE"]
  info_plist_path = PROJECT_ROOT_DIR + info_plist
  plist = Plist.parse_xml info_plist_path
  xcode_version = plist["CFBundleShortVersionString"]
  xcode_build = plist["CFBundleVersion"].to_i
  content['xcode_version'] = "#{xcode_version}"
  content['xcode_build'] = "#{xcode_build}"

  profiles << '|' unless profiles.empty?
  certificates << '|' unless profiles.empty?
  passwords << '|' unless profiles.empty?

  certificates << "file://./#{val['settings']['certificate']}"
  profiles << "file://./#{val['settings']['provisioning-profile']}"

  build_config[key] = content
}

certificates << "|file://./Signing/enterprise.p12"
passwords << "|"
profiles << "|file://./Signing/enterprise.mobileprovision"

# Save to env
system "bitrise envman add --key BUILD_CONFIG --value '#{build_config.to_json}' --no-expand"
system "bitrise envman add --key BITRISE_CERTIFICATE_URL --value '#{certificates}' --no-expand"
system "bitrise envman add --key BITRISE_CERTIFICATE_PASSPHRASE --value '#{passwords}' --no-expand"
system "bitrise envman add --key BITRISE_PROVISION_URL --value '#{profiles}' --no-expand"
system "bitrise envman add --key HOCKEY_UPLOAD_FLAG --value '#{hockey_upload}' --no-expand"
system "bitrise envman add --key TESTFLIGHT_UPLOAD_FLAG --value '#{testflight_upload}' --no-expand"
puts green "|- Succesfully generated build config."
pp build_config unless not VERBOSE
