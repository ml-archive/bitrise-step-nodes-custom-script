#!/usr/bin/env ruby

require 'pp'
require 'json'

HOCKEY_BASE_URL = 'https://rink.hockeyapp.net/apps/'

config = JSON.parse ENV['BUILD_CONFIG']

message = ""

config.each_pair { |target, info|
	hockeyURL = HOCKEY_BASE_URL + info["hockey-app-id"]
	scheme = info["scheme"]
	configuration = info["configuration"]
	version = "#{info["xcode_version"]} (#{info["xcode_build"]})"

	puts "Hockey URL: #{hockeyURL}"
	puts "Scheme: #{scheme}"
	puts "Configuration: #{configuration}"
	puts ("Version: #{version}")
	message += "#{info["scheme"]} #{info["configuration"]} \n Version #{version} \n"
	if ENV['HOCKEY_UPLOAD_FLAG'] == '1'
		message += "#{hockeyURL} \n"	
	else 
		message += "Hockey upload disabled \n"
	end 

	if ENV['TESTFLIGHT_UPLOAD_FLAG'] == '1'
		message += "New build processing on Testflight \n\n"
	else 
		message += "Testflight build disabled \n\n"
	end

	if ENV['HOCKEY_UPLOAD_FLAG'] == '0' && ENV['TESTFLIGHT_UPLOAD_FLAG'] == '0'
		message += "Why did you even make this build? :thinking_face: \n\n"
	end 
}

system "bitrise envman add --key SLACK_MESSAGE --value '#{message}' --no-expand"
