$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH << File.expand_path( File.dirname(__FILE__) + '/../lib' )
require 'rubygems'
require 'net/dav'
require 'spec'
require 'spec/autorun'
require 'webdav_server'

Spec::Runner.configure do |config|

end

# Profind helper. Returns properties or error
def find_props_or_error(dav, path)
  begin
    return dav.propfind(path).to_s
  rescue Net::HTTPServerException => e
    return e.to_s
  end
end
