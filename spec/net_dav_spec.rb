require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Net::Dav" do

  before(:all) do
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

  it "should write files to webdav server" do
    dav = Net::DAV.new("http://localhost:10080/")
    @props = find_props_or_error(dav, "/new_file.html")
    @props.should match(/404.*Not found/i)

    dav.put_string("/new_file.html","File contents")

    @props = find_props_or_error(dav, "/new_file.html")
    @props.should match(/200 OK/i)
  end

  it "should delete files from webdav server" do
    dav = Net::DAV.new("http://localhost:10080/")

    @props = find_props_or_error(dav, "/new_file.html")
    @props.should match(/200 OK/i)
    puts "DEBUG delete spec"

    dav.delete("/new_file.html")
    @props = find_props_or_error(dav, "/new_file.html")
    @props.should match(/404.*Not found/i)
  end

  after(:all) do
    # Shut down webdav server
    Process.kill('SIGKILL', @pid) rescue nil
  end

end
