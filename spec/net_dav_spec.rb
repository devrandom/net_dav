require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Net::Dav" do

  serverpid = nil

  before(:all) do
    # This is run once and only once, before all of the examples
    # and before any before(:each) blocks.

    # Start webdav server in subprocess
    @pid = fork do
      webdav_server(:port => 10080,:authentication => false)
    end
    # Wait for webdavserver to start
    sleep(2)
  end

  it "should create a Net::Dav object" do
    Net::DAV.new("http://localhost.localdomain/").should_not be_nil
  end

   it "should read properties from webdav server" do
     dav = Net::DAV.new("http://localhost:10080/")
     @props = dav.propfind("/").to_s
     @props.should match(/200 OK/)
   end

  after(:all) do
    # this is run once and only once after all of the examples
    # and after any after(:each) blocks
    Process.kill('SIGKILL', @pid) rescue nil
  end

end
