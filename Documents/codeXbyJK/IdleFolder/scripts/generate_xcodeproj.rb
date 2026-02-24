#!/usr/bin/env ruby
require 'xcodeproj'
require 'fileutils'

project_path = File.expand_path('../IdleFolder.xcodeproj', __dir__)
app_source_root = File.expand_path('../IdleFolderApp', __dir__)
test_source_root = File.expand_path('../IdleFolderTests', __dir__)
ext_source_root = File.expand_path('../Extensions/DeviceActivityReportExtension', __dir__)
development_team = ENV.fetch('IOS_DEVELOPMENT_TEAM', 'MY5TQDBX97')

FileUtils.rm_rf(project_path) if File.exist?(project_path)

project = Xcodeproj::Project.new(project_path)
project.root_object.attributes['LastUpgradeCheck'] = '2620'

main_group = project.main_group
app_group = main_group.new_group('IdleFolderApp', app_source_root)
test_group = main_group.new_group('IdleFolderTests', test_source_root)
ext_group = main_group.new_group('DeviceActivityReportExtension', ext_source_root)

app_target = project.new_target(:application, 'IdleFolder', :ios, '17.0')
app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.IdleFolder'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  config.build_settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone'] = 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'IdleFolderApp/IdleFolder.entitlements'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

Dir.glob(File.join(app_source_root, '**', '*.swift')).sort.each do |file_path|
  relative = file_path.sub(%r{^#{Regexp.escape(app_source_root)}/?}, '')
  file_ref = app_group.new_file(relative)
  app_target.add_file_references([file_ref])
end

assets_catalog = File.join(app_source_root, 'Assets.xcassets')
if Dir.exist?(assets_catalog)
  assets_ref = app_group.new_file('Assets.xcassets')
  app_target.resources_build_phase.add_file_reference(assets_ref, true)
end

ext_target = project.new_target(:app_extension, 'DeviceActivityReportExtension', :ios, '17.0')
ext_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.IdleFolder.DeviceActivityReportExtension'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Extensions/DeviceActivityReportExtension/DeviceActivityReportExtension.entitlements'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  config.build_settings['SKIP_INSTALL'] = 'YES'
end

Dir.glob(File.join(ext_source_root, '**', '*.swift')).sort.each do |file_path|
  relative = file_path.sub(%r{^#{Regexp.escape(ext_source_root)}/?}, '')
  file_ref = ext_group.new_file(relative)
  ext_target.add_file_references([file_ref])
end

# Share snapshot model/aggregation code with extension target.
shared_files = [
  'IdleFolderApp/Data/UsageSnapshotStore.swift',
  'IdleFolderApp/Data/UsageSnapshotFactory.swift'
]

shared_files.each do |path|
  file_ref = main_group.new_file(path)
  ext_target.add_file_references([file_ref])
end

test_target = project.new_target(:unit_test_bundle, 'IdleFolderTests', :ios, '17.0')
test_target.add_dependency(app_target)

test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.IdleFolderTests'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['DEVELOPMENT_TEAM'] = development_team
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/IdleFolder.app/IdleFolder'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
end

Dir.glob(File.join(test_source_root, '**', '*.swift')).sort.each do |file_path|
  relative = file_path.sub(%r{^#{Regexp.escape(test_source_root)}/?}, '')
  file_ref = test_group.new_file(relative)
  test_target.add_file_references([file_ref])
end

project.recreate_user_schemes
project.save
puts "Generated #{project_path}"
