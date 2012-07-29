require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/webdav_server')

describe "Net::Dav" do
  before(:all) do
    @server_uri = "http://localhost:10080/"
    @new_file_uri = "/new_file.html"
    @copied_file_uri = "/copied_file.html"
    @moved_file_uri = "/moved_file.html"

    # Start webdav server in subprocess
    @pid = fork do
      webdav_server(:port => 10080, :authentication => false)
    end
    # Wait for webdavserver to start
    wait_for_server(@server_uri)
  end

  before(:each) do
    @dav = Net::DAV.new(@server_uri)

    # Delete any files that are created by the specs
    [@new_file_uri, @copied_file_uri, @moved_file_uri].each do |uri|
      if (find_props_or_error(@dav, uri) =~ /200/)
        @dav.delete(uri)
      end
    end
  end

  it "should create a Net::Dav object" do
    @dav.should_not be_nil
  end

  it "should read properties from webdav server" do
    @props = @dav.propfind("/").to_s
    @props.should match(/200 OK/)
  end

  it "should store the HTTP status in @status" do
    dav = Net::DAV.new("http://localhost:10080/")
    @props = dav.propfind("/").to_s

    dav.last_status.should == 207
  end

  it "should raise if finding non-existent path" do
    lambda do
      @dav.find("/") do |item|
      end
    end.should_not raise_error
  end

  it "should raise if finding non-existent path" do
    lambda do
      @dav.find("/asdf") do |item|
      end
    end.should raise_error Net::HTTPServerException
  end

  it "should write files to webdav server" do
    @props = find_props_or_error(@dav, @new_file_uri)
    @props.should match(/404.*Not found/i)

    @dav.put_string(@new_file_uri,"File contents")
    @dav.last_status.should == 200

    @props = find_props_or_error(@dav, @new_file_uri )
    @props.should match(/200 OK/i)
  end

  it "should delete files from webdav server" do
    @dav.put_string(@new_file_uri,"File contents")

    @props = find_props_or_error(@dav, @new_file_uri)
    @props.should match(/200 OK/i)

    @dav.delete(@new_file_uri)
    @dav.last_status.should == 204

    @props = find_props_or_error(@dav, @new_file_uri)
    @props.should match(/404.*Not found/i)

  end

  # TODO: This test seems to assume file.html already exists on the server.
  it "should copy files on webdav server" do
    @props = find_props_or_error(@dav, "/file.html")
    @props.should match(/200 OK/i)

    @dav.copy("/file.html", @copied_file_uri)
    dav.last_status.should == 201

    @props = find_props_or_error(@dav, @copied_file_uri)
    @props.should match(/200 OK/i)

    @dav.delete(@copied_file_uri)

    @props = find_props_or_error(@dav, @copied_file_uri)
    @props.should match(/404.*Not found/i)
  end

  # TODO: This test seems to assume file.html already exists on the server.
  it "should move files on webdav server" do
    @props = find_props_or_error(@dav, "/file.html")
    @props.should match(/200 OK/i)

    @dav.move("/file.html", @moved_file_uri)
    dav.last_status.should == 201

    @props = find_props_or_error(@dav,  @moved_file_uri)
    @props.should match(/200 OK/i)

    @props = find_props_or_error(@dav, "/file.html")
    @props.should match(/404.*Not found/i)

    @dav.move( @moved_file_uri,"/file.html")
    @props = find_props_or_error(@dav, "/file.html")
    @props.should match(/200 OK/i)
  end

  it "should retrieve acl" do
    @props = @dav.propfind("/", :acl).to_s
    @props.should match(/200 OK/i)
  end

  it "should detect if resource or collection exists on server" do
    @dav.put_string( @new_file_uri, "File" )

    @dav.exists?(@new_file_uri).should == true
    @dav.exists?('/totally_unknown_file.html').should == false
  end

# proppatch seems to work, but our simple webdav server don't update properties
#   it "should alter properties on resources on webdav server" do
#     dav = Net::DAV.new(@server_uri)
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
