require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "NetDav" do

  it "should be able to do propfind in a folder" do
    dav = Net::DAV.new("http://localhost:10080/")
    props = dav.propfind("/")
  end

end
