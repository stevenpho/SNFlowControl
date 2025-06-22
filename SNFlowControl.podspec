Pod::Spec.new do |s|
  s.name         = "SNFlowControl"
  s.version      = "1.1.2"
  s.summary      = "A lightweight flow control."
  s.description  = "A lightweight flow control make code readability"
  s.homepage     = "https://github.com/stevenpho/SNFlowControl"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "Steven" => "" }
  
  s.requires_arc = true
  s.platform = :ios, "13.0"
  s.swift_version = "5.0"
  s.osx.deployment_target = "10.13"
  s.ios.deployment_target = "9.0"
  s.watchos.deployment_target = "3.0"
  s.tvos.deployment_target = "9.0"
  s.source   = { :git => "https://github.com/stevenpho/SNFlowControl.git", :tag => "#{s.version}" }
  s.source_files  = "SNFlowControl/Classes/**/*"
  s.resource_bundles = {'SNFlowControl' => ['SNFlowControl/Assets/PrivacyInfo.xcprivacy']}
end
