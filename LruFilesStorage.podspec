Pod::Spec.new do |s|
  s.name = 'LruFilesStorage'
  s.platform = :ios, '7.0'
  s.version = '0.0.1'
  s.summary = 'LRU (least recently used) system for storing files on disk for iOS in Objective-C'
  s.homepage = 'https://github.com/blackm00n/LruFilesStorage'
  s.license = 'MIT'
  s.author = { 'Aleksey Kozhevnikov' => 'aleksey.kozhevnikov@gmail.com' }
  s.source = { :git => 'https://github.com/blackm00n/LruFilesStorage.git', :tag => "v#{s.version.to_s}" }
  s.source_files = 'LruFilesStorage/LruFilesStorage'
  s.requires_arc = true
  s.dependency 'FMDB', '~> 2.5'
  s.dependency 'AKLruDictionary', '~> 2.0'
end
