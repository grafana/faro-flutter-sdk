#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint faro.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'faro'
  s.version          = '0.15.0'
  s.summary          = 'Grafana Faro SDK for Flutter - mobile observability and real user monitoring.'
  s.description      = <<-DESC
Grafana Faro SDK for Flutter applications. Monitor your Flutter app with ease
using real user monitoring, error tracking, and distributed tracing.
                       DESC
  s.homepage         = 'https://github.com/grafana/faro-flutter-sdk'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = 'Grafana Labs'
  s.source           = { :path => '.' }
  s.source_files = 'faro/Sources/faro/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'PLCrashReporter'
  s.static_framework = true
  s.ios.deployment_target = '13.0'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
