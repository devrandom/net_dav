$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'net/dav'
require 'spec'
require 'spec/autorun'
require 'webdav_server'

Spec::Runner.configure do |config|

end
