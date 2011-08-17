require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/webdav_server')

describe "Net::Dav" do

  before(:all) do
    # Start webdav server in subprocess
    @pid = fork do
      webdav_server(:port => 10080, :authentication => false)
    end
    # Wait for webdavserver to start
    wait_for_server("http://localhost:10080/")
  end

  it "should create a Net::Dav object" do
    Net::DAV.new("http://localhost.localdomain/").should_not be_nil
  end

  it "should read properties from webdav server" do
    dav = Net::DAV.new("http://localhost:10080/")
    @props = dav.propfind("/").to_s
    @props.should match(/200 OK/)
  end

  it "should store the HTTP status in @status" do
    dav = Net::DAV.new("http://localhost:10080/")
    @props = dav.propfind("/").to_s

    dav.last_status.should == 207
  end

  it "should raise if finding non-existent path" do
    dav = Net::DAV.new("http://localhost:10080/")
    lambda do
      dav.find("/") do |item|
      end
    end.should_not raise_error
  end

  it "should raise if finding non-existent path" do
    dav = Net::DAV.new("http://localhost:10080/")
    lambda do
      dav.find("/asdf") do |item|
      end
    end.should raise_error Net::HTTPServerException
  end

  it "should write files to webdav server" do
    dav = Net::DAV.new("http://localhost:10080/")
    @props = find_props_or_error(dav, "/new_file.html")
    @props.should match(/404.*Not found/i)

    dav.put_string("/new_file.html","File contents")
    dav.last_status.should == 200

    @props = find_props_or_error(dav, "/new_file.html")
    @props.should match(/200 OK/i)
  end

   it "should delete files from webdav server" do
     dav = Net::DAV.new("http://localhost:10080/")

     @props = find_props_or_error(dav, "/new_file.html")
     @props.should match(/200 OK/i)

     dav.delete("/new_file.html")
     dav.last_status.should == 204

     @props = find_props_or_error(dav, "/new_file.html")
     @props.should match(/404.*Not found/i)

   end

  it "should copy files on webdav server" do
    dav = Net::DAV.new("http://localhost:10080/")

    @props = find_props_or_error(dav, "/file.html")
    @props.should match(/200 OK/i)

    dav.copy("/file.html","/copied_file.html")
    dav.last_status.should == 201

    @props = find_props_or_error(dav, "/copied_file.html")
    @props.should match(/200 OK/i)

    dav.delete("/copied_file.html")

    @props = find_props_or_error(dav, "/copied_file.html")
    @props.should match(/404.*Not found/i)
  end

  it "should move files on webdav server" do
    dav = Net::DAV.new("http://localhost:10080/")

    @props = find_props_or_error(dav, "/file.html")
    @props.should match(/200 OK/i)

    dav.move("/file.html","/moved_file.html")
    dav.last_status.should == 201

    @props = find_props_or_error(dav, "/moved_file.html")
    @props.should match(/200 OK/i)

    @props = find_props_or_error(dav, "/file.html")
    @props.should match(/404.*Not found/i)

    dav.move("/moved_file.html","/file.html")
    @props = find_props_or_error(dav, "/file.html")
    @props.should match(/200 OK/i)
  end

  it "should retrieve acl" do
    dav = Net::DAV.new("http://localhost:10080/")
    @props = dav.propfind("/", :acl).to_s
    @props.should match(/200 OK/i)
  end

  it "should detect if resource or collection exists on server" do
    dav = Net::DAV.new("http://localhost:10080/")
    dav.exists?('/file.html').should == true
    dav.exists?('/totally_unknown_file.html').should == false
  end

# proppatch seems to work, but our simple webdav server don't update properties
#   it "should alter properties on resources on webdav server" do
#     dav = Net::DAV.new("http://localhost:10080/")
#     @props = find_props_or_error(dav, "/file.html")
#     puts @props
#     dav.proppatch("/file.html", "<d:resourcetype>static-file</d:resourcetype>")
#     @props = find_props_or_error(dav, "/file.html")
#     puts @props
#   end

  after(:all) do
    # Shut down webdav server
    Process.kill('SIGKILL', @pid) rescue nil
  end

end
