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

def addErrorMessage(message)  
  File.open('error_message', 'w') { |file| file.write(message) }
end

# -------
# Main
# -------

# Load YAML
puts bold "Loading settings from #{PROJECT_FILE_NAME}"
unless File.exist?(PROJECT_FILE_NAME)
  message = "|- Couldn't find project.yml file" 
  addErrorMessage(message)
  raise red message
end

project_settings = YAML.load_file(PROJECT_FILE_NAME)

# Load some settings
xcodeproj_path = project_settings['xcodeproj']
configuration = project_settings["configuration"]
PROJECT_ROOT_DIR = File.dirname(xcodeproj_path) + "/"
export_method = project_settings['method'] ||= "app-store" 

# Load Xcode project
unless File.exist?(xcodeproj_path)
  message = "|- Couldn't find Xcode project at: #{xcodeproj_path}" 
  addErrorMessage(message)
  raise red message
end

xcode_project = Xcodeproj::Project.open xcodeproj_path

# Validate configuration
avialable_configurations = xcode_project.build_configurations.map { |x|
  puts "|- #{x.name}" if VERBOSE
  x.name
}
unless avialable_configurations.include? configuration
  message = "|- Can't find configuration #{configuration}"
  addErrorMessage(message)
  raise red message
end

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
  message = "|- No valid targets to build, build failed."
  addErrorMessage(message)
  raise red message
end

# Temp fix for riide, will make this more reusable in the future. This breaks down the
# targets into groups of 6, and uses the RIIDE_PROJECT env var to determine which 
# of the subset to use
length = 6
if validated_targets.count > length   
  start = ENV["RIIDE_PROJECT"].to_i * length
  start -= length 
  validated_targets = validated_targets.select { |k, v| validated_targets.keys[start, length].include? k }  
end 

puts ""
puts bold "Starting Hockey versions verification"

valid = true

unless DEBUG_MODE
  # Get version and build numbers
  message = ""
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

    # Check if hockey id is filled in correctly
    if hockey_app_id.nil? || hockey_app_id.empty? then
      raise red """|- HockeyApp app id is missing, can't continue with build as version and build number can't be verified. 
      All apps should have an associated HockeyApp app."""
    end

    buildnumber = HockeyVer.parse_hockey_version hockey_app_id, ENV["HOCKEY_API_TOKEN"]

    # Check if build number from hockey is nil
    if buildnumber.nil? 
      puts yellow "|- No build found on Hockey, proceeding with build"
      next
    end

    hockey_version = buildnumber["version"]
    hockey_build = buildnumber["build"].to_i

    # Compare, make sure that build is always higher and version is at least higher or equal
    unless (Version.new(xcode_version) >= Version.new(hockey_version)) && (xcode_build > hockey_build)
      valid = false
      warning_message = """#{key}: Xcode version #{xcode_version} (#{xcode_build}) is lower or equal than the one on Hockey #{hockey_version} (#{hockey_build})."""
      message +="#{warning_message} \n"
      puts yellow "|- #{warning_message}"
    end
  }
end

# Check if we can continue
unless valid
  message += "Can't continue with build, as version and build numbers must be higher than the ones on Hockey." 
  addErrorMessage(message)
  raise red message
end


# All done
puts green "|- All version and build numbers are correct."

puts ""
puts bold "Creating information required for build"

build_config = Hash.new

validated_targets.each_pair { |key, val|
  content = val['settings']

  # Pass platform, xcodeproj
  content['xcodeproj'] = xcode_project.path.to_path
  content['workspace'] = project_settings['workspace']
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

  build_config[key] = content
}

# Save to env
system "bitrise envman add --key BUILD_CONFIG --value '#{build_config.to_json}' --no-expand" unless DEBUG_MODE
system "bitrise envman add --key EXPORT_METHOD --value #{export_method} --no-expand" unless DEBUG_MODE
system "bitrise envman add --key HOCKEY_UPLOAD_FLAG --value '#{hockey_upload}' --no-expand" unless DEBUG_MODE
system "bitrise envman add --key TESTFLIGHT_UPLOAD_FLAG --value '#{testflight_upload}' --no-expand" unless DEBUG_MODE
system "bitrise envman add --key SLACK_CHANNEL --value '#{project_settings['slack-channel']}' --no-expand " unless DEBUG_MODE
puts green "|- Succesfully generated build config."
pp build_config unless not VERBOSE
