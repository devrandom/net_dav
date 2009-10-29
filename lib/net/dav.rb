require 'net/https'
require 'uri'
require 'nokogiri'
require 'net/dav/item'

module Net #:nodoc:
  # Implement a WebDAV client
  class DAV
    # Seconds to wait until reading one block (by one system call).
    # If the DAV object cannot read a block in this many seconds,
    # it raises a TimeoutError exception.
    #
    def read_timeout
      @http.read_timeout
    end

    def read_timeout=(sec)
      @http.read_timeout = sec
    end

    # Seconds to wait until connection is opened.
    # If the DAV object cannot open a connection in this many seconds,
    # it raises a TimeoutError exception.
    #
    def open_timeout
      @http.read_timeout
    end

    def open_timeout=(sec)
      @http.read_timeout = sec
    end

    # Creates a new Net::DAV object and opens the connection
    # to the host.  Yields the object to the block.
    #
    # Example:
    #
    #  res = Net::DAV.start(url) do |dav|
    #    dav.find(url.path) do |item|
    #      puts "#{item.uri} is size #{item.size}"
    #    end
    #  end
    def self.start(uri, &block) # :yield: dav
      new(uri).start(&block)
    end

    # Creates a new Net::DAV object for the specified host
    # The path part of the URI is used to handle relative URLs
    # in subsequent requests.
    def initialize(uri)
      @uri = uri
      @uri = URI.parse(@uri) if @uri.is_a? String
      case @uri.scheme
      when "http"
	@http = Net::HTTP.new(@uri.host, @uri.port)
      when "https"
	@http = Net::HTTPS.new(@uri.host, @uri.port)
      else
	raise "unknown uri scheme"
      end
    end

    # Opens the connection to the host.  Yields self to the block.
    #
    # Example:
    #
    #  res = Net::DAV.new(url).start do |dav|
    #    dav.find(url.path) do |item|
    #      puts item.inspect
    #    end
    #  end
    def start # :yield: dav
      @http.start do |http|
	return yield(self)
      end
    end

    # Set credentials for basic authentication
    def credentials(user, pass)
      @user = user
      @pass = pass
    end

    def propfind(path) #:nodoc:
      req = Net::HTTP::Propfind.new(path)
      req.body = '<?xml version="1.0" encoding="utf-8"?><DAV:propfind xmlns:DAV="DAV:"><DAV:allprop/></DAV:propfind>'
      req['Depth'] = '1'
      req.content_type = 'text/xml; charset="utf-8"'
      if (@user)
	req.basic_auth @user, @pass
      end
      res = @http.request(req)
      res.value # raises error if not success
      Nokogiri::XML.parse(res.body)
    end

    # Find files and directories, yields Net::DAV::Item
    #
    # Examples:
    #
    #  res = Net::DAV.start(url) do |dav|
    #    dav.find(url.path, :recursive => true) do |item|
    #      puts "#{item.type} #{item.uri}"
    #      puts item.content
    #    end
    #  end
    def find(path, options = {})
      namespaces = {'x' => "DAV:"}
      doc = propfind(path)
      path.sub!(/\/$/, '')
      doc./('.//x:response', namespaces).each do |item|
	uri = @uri.merge(item.xpath("x:href", namespaces).inner_text)
	size = item.%(".//x:getcontentlength", namespaces).inner_text rescue nil
	type = item.%(".//x:collection", namespaces) ? :directory : :file
	res = Item.new(self, uri, type, size)
	if type == :file
	  yield res
	elsif uri.path == path || uri.path == path + "/"
	  # This is the top-level dir, skip it
	elsif options[:recursive] && type == :directory
	  yield res
	  # This is a subdir, recurse
	  find(uri.path, options) do |sub_res|
	    yield sub_res
	  end
	else
	  yield res
	end
      end
    end

    # Change the base URL for use in handling relative paths
    def cd(url)
      new_uri = @uri.merge(url)
      if new_uri.host != @uri.host || new_uri.port != @uri.port || new_uri.scheme != @uri.scheme
	raise Exception , "uri must have same scheme, host and port"
      end
      @uri = new_uri
    end

    # Get the content of a resource as a string
    #
    # If called with a block, yields each fragment of the
    # entity body in turn as a string as it is read from
    # the socket.  Note that in this case, the returned response
    # object will *not* contain a (meaningful) body.

    def get(path, &block)
      req = Net::HTTP::Get.new(path)
      req.content_type = 'text/xml; charset="utf-8"'
      if (@user)
	req.basic_auth @user, @pass
      end
      res = nil
      @http.request(req) {|response|
	response.read_body nil, &block
	res = response
      }
      res.body
    end

    # Stores the content of a stream to a URL
    #
    # Example:
    # File.open(file, "r") do |stream|
    #   dav.put(url.path, stream, File.size(file))
    # end
    def put(path, stream, length)
      req = Net::HTTP::Put.new(path)
      req.content_type = 'text/xml; charset="utf-8"'
      req.content_length = length
      req.body_stream = stream
      #req['transfer-encoding'] = 'chunked'
      if (@user)
	req.basic_auth @user, @pass
      end
      res = @http.request(req)
      res.value
      res.body
    end

    # Stores the content of a string to a URL
    #
    # Example:
    #   dav.put(url.path, "hello world")
    #
    def put_string(path, str)
      req = Net::HTTP::Put.new(path)
      req.content_type = 'text/xml; charset="utf-8"'
      req.body = str
      #req['transfer-encoding'] = 'chunked'
      if (@user)
	req.basic_auth @user, @pass
      end
      res = @http.request(req)
      res.value
      res.body
    end


    # Makes a new directory (collection)
    def mkdir(path)
      req = Net::HTTP::Mkcol.new(path)
      req.content_type = 'text/xml; charset="utf-8"'
      if (@user)
	req.basic_auth @user, @pass
      end
      res = @http.request(req)
      res.value
      res.body
    end

  end
end
