Pod::Spec.new do |spec|

  spec.name         = "FlatStore"
  spec.version      = "0.0.1"
  spec.summary      = "FlatStore is a memory-only data storage library written at Eureka."

  spec.description  = <<-DESC
    FlatStore is a memory-only data storage library written at Eureka.
    And it's able to observe data changed.
                   DESC
  spec.homepage     = "https://github.com/eure/FlatStore"
  spec.license      = "MIT"
 
  spec.authors      = { "Muukii" => "muukii.app@gmail.com" }

  spec.ios.deployment_target = "10.0"
  spec.osx.deployment_target = "10.12"
  # spec.watchos.deployment_target = "2.0"
  # spec.tvos.deployment_target = "9.0"

  spec.source        = { :git => "https://github.com/eure/FlatStore.git", :tag => "#{spec.version}" }

  spec.source_files  = "FlatStore/**/*.swift"

  # spec.public_header_files = "Classes/**/*.h"

  spec.frameworks = "Foundation"
  spec.requires_arc = true
end
