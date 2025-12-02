#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint faro.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'faro'
  s.version          = '0.7.0'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'PLCrashReporter'
  s.static_framework = true
  s.ios.deployment_target = '11.0'
  s.platform = :ios, '11.0'
  s.preserve_paths = 'CrashReporter.xcframework'
  s.vendored_frameworks = 'CrashReporter.xcframework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
