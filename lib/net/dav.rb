require 'net/https'
require 'uri'
require 'nokogiri'
require 'net/dav/item'
require 'base64'
require 'digest/md5'
begin
  require 'curb'
rescue LoadError
end

module Net #:nodoc:
  # Implement a WebDAV client
  class DAV
    MAX_REDIRECTS = 10

    def last_status
      @handler.last_status
    end

    class NetHttpHandler
      attr_writer :user, :pass

      attr_accessor :disable_basic_auth
      attr_reader :last_status


      def verify_callback=(callback)
        @http.verify_callback = callback
      end

      def verify_server=(value)
        @http.verify_mode = value ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      def initialize(uri)
        @disable_basic_auth = false
        @uri = uri
        case @uri.scheme
        when "http"
          @http = Net::HTTP.new(@uri.host, @uri.port)
        when "https"
          @http = Net::HTTP.new(@uri.host, @uri.port)
          @http.use_ssl = true
          self.verify_server = true
        else
          raise "unknown uri scheme"
        end
      end

      def start(&block)
        @http.start(&block)
      end

      def read_timeout
        @http.read_timeout
      end

      def read_timeout=(sec)
        @http.read_timeout = sec
      end

      def open_timeout
        @http.read_timeout
      end

      def open_timeout=(sec)
        @http.read_timeout = sec
      end

      def request_sending_stream(verb, path, stream, length, headers)
        headers ||= {}
        headers = {"User-Agent" => "Ruby"}.merge(headers)
        req =
          case verb
          when :put
            Net::HTTP::Put.new(path)
          else
            raise "unkown sending_stream verb #{verb}"
          end
        req.body_stream = stream
        req.content_length = length
        headers.each_pair { |key, value| req[key] = value } if headers
        req.content_type = 'application/octet-stream'
        res = handle_request(req, headers)
        res
      end

      def request_sending_body(verb, path, body, headers)
        headers ||= {}
        headers = {"User-Agent" => "Ruby"}.merge(headers)
        req =
          case verb
          when :put
            Net::HTTP::Put.new(path)
          else
            raise "unkown sending_body verb #{verb}"
          end
        req.body = body
        headers.each_pair { |key, value| req[key] = value } if headers
        req.content_type = 'application/octet-stream'
        res = handle_request(req, headers)
        res
      end

      def request_returning_body(verb, path, headers, &block)
        headers ||= {}
        headers = {"User-Agent" => "Ruby"}.merge(headers)
        req =
          case verb
          when :get
            Net::HTTP::Get.new(path)
          else
            raise "unkown returning_body verb #{verb}"
          end
        headers.each_pair { |key, value| req[key] = value } if headers
        res = handle_request(req, headers, MAX_REDIRECTS, &block)
        res.body
      end

      def request(verb, path, body, headers)
        headers ||= {}
        headers = {"User-Agent" => "Ruby"}.merge(headers)
        req =
          case verb
          when :propfind
            Net::HTTP::Propfind.new(path)
          when :mkcol
            Net::HTTP::Mkcol.new(path)
          when :delete
            Net::HTTP::Delete.new(path)
          when :move
            Net::HTTP::Move.new(path)
          when :copy
            Net::HTTP::Copy.new(path)
          when :proppatch
            Net::HTTP::Proppatch.new(path)
          when :lock
            Net::HTTP::Lock.new(path)
          when :unlock
            Net::HTTP::Unlock.new(path)
          else
            raise "unkown verb #{verb}"
          end
        req.body = body
        headers.each_pair { |key, value| req[key] = value } if headers
        req.content_type = 'text/xml; charset="utf-8"'
        res = handle_request(req, headers)
        res
      end

      def handle_request(req, headers, limit = MAX_REDIRECTS, &block)
        # You should choose better exception.
        raise ArgumentError, 'HTTP redirect too deep' if limit == 0

        case @authorization
        when :basic
          req.basic_auth @user, @pass
        when :digest
          digest_auth(req, @user, @pass, response)
        end

        response = nil
        if block
          @http.request(req) {|res|
            # Only start returning a body if we will not retry
            res.read_body nil, &block if !res.is_a?(Net::HTTPUnauthorized) && !res.is_a?(Net::HTTPRedirection)
            response = res
          }
        else
          response = @http.request(req)
        end

        @last_status = response.code.to_i
        case response
        when Net::HTTPSuccess     then
          return response
        when Net::HTTPUnauthorized     then
          response.error! unless @user
          response.error! if req['authorization']
          new_req = clone_req(req.path, req, headers)
          if response['www-authenticate'] =~ /^basic/i
            if disable_basic_auth
              raise "server requested basic auth, but that is disabled"
            end
            @authorization = :basic
          else
            @authorization = :digest
          end
          return handle_request(req, headers, limit - 1, &block)
        when Net::HTTPRedirection then
          location = URI.parse(response['location'])
          if (@uri.scheme != location.scheme ||
              @uri.host != location.host ||
              @uri.port != location.port)
            raise ArgumentError, "cannot redirect to a different host #{@uri} => #{location}"
          end
          new_req = clone_req(location.path, req, headers)
          return handle_request(new_req, headers, limit - 1, &block)
        else
          response.error!
        end
      end

      def clone_req(path, req, headers)
        new_req = req.class.new(path)
        new_req.body = req.body if req.body
        if (req.body_stream)
          req.body_stream.rewind
          new_req.body_stream = req.body_stream
        end
        new_req.content_length = req.content_length if req.content_length
        headers.each_pair { |key, value| new_req[key] = value } if headers
        return new_req
      end

      CNONCE = Digest::MD5.hexdigest("%x" % (Time.now.to_i + rand(65535))).slice(0, 8)

      def digest_auth(request, user, password, response)
        # based on http://segment7.net/projects/ruby/snippets/digest_auth.rb
        @nonce_count = 0 if @nonce_count.nil?
        @nonce_count += 1

        raise "bad www-authenticate header" unless (response['www-authenticate'] =~ /^(\w+) (.*)/)

        params = {}
        $2.gsub(/(\w+)="(.*?)"/) { params[$1] = $2 }

        a_1 = "#{user}:#{params['realm']}:#{password}"
        a_2 = "#{request.method}:#{request.path}"
        request_digest = ''
        request_digest << Digest::MD5.hexdigest(a_1)
        request_digest << ':' << params['nonce']
        request_digest << ':' << ('%08x' % @nonce_count)
        request_digest << ':' << CNONCE
        request_digest << ':' << params['qop']
        request_digest << ':' << Digest::MD5.hexdigest(a_2)

        header = []
        header << "Digest username=\"#{user}\""
        header << "realm=\"#{params['realm']}\""
        header << "nonce=\"#{params['nonce']}\""
        header << "uri=\"#{request.path}\""
        header << "cnonce=\"#{CNONCE}\""
        header << "nc=#{'%08x' % @nonce_count}"
        header << "qop=#{params['qop']}"
        header << "response=\"#{Digest::MD5.hexdigest(request_digest)}\""
        header << "algorithm=\"MD5\""

        header = header.join(', ')
        request['Authorization'] = header
      end
    end


    class CurlHandler < NetHttpHandler
      def verify_callback=(callback)
        super
        curl = make_curl
        $stderr.puts "verify_callback not implemented in Curl::Easy"
      end

      def verify_server=(value)
        super
        curl = make_curl
        curl.ssl_verify_peer = value
        curl.ssl_verify_host = value
      end

      def make_curl
        unless @curl
          @curl = Curl::Easy.new
          @curl.timeout = @http.read_timeout
          @curl.follow_location = true
          @curl.max_redirects = MAX_REDIRECTS
          if disable_basic_auth
            @curl.http_auth_types = Curl::CURLAUTH_DIGEST
          end
        end
        @curl
      end

      def request_returning_body(verb, path, headers)
        raise "unkown returning_body verb #{verb}" unless verb == :get
        url = @uri.merge(path)
        curl = make_curl
        curl.url = url.to_s
        headers.each_pair { |key, value| curl.headers[key] = value } if headers
        if (@user)
          curl.userpwd = "#{@user}:#{@pass}"
        else
          curl.userpwd = nil
        end
        res = nil
        if block_given?
          curl.on_body do |frag|
            yield frag
            frag.length
          end
        end
        curl.perform

        @last_status = curl.response_code

        unless curl.response_code >= 200 && curl.response_code < 300
          header_block = curl.header_str.split(/\r?\n\r?\n/)[-1]
          msg = header_block.split(/\r?\n/)[0]
          msg.gsub!(/^HTTP\/\d+.\d+ /, '')
          raise Net::HTTPError.new(msg, nil)
        end
        curl.body_str
      end

    end

    # Disable basic auth - to protect passwords from going in the clear
    # through a man-in-the-middle attack.
    def disable_basic_auth?
      @handler.disable_basic_auth
    end

    def disable_basic_auth=(value)
      @handler.disable_basic_auth = value
    end

    # Seconds to wait until reading one block (by one system call).
    # If the DAV object cannot read a block in this many seconds,
    # it raises a TimeoutError exception.
    #
    def read_timeout
      @handler.read_timeout
    end

    def read_timeout=(sec)
      @handler.read_timeout = sec
    end

    # Seconds to wait until connection is opened.
    # If the DAV object cannot open a connection in this many seconds,
    # it raises a TimeoutError exception.
    #
    def open_timeout
      @handler.read_timeout
    end

    def open_timeout=(sec)
      @handler.read_timeout = sec
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
    def self.start(uri, options = nil, &block) # :yield: dav
      new(uri, options).start(&block)
    end

    # Creates a new Net::DAV object for the specified host
    # The path part of the URI is used to handle relative URLs
    # in subsequent requests.
    # You can pass :curl => false if you want to disable use
    # of the curb (libcurl) gem if present for acceleration
    def initialize(uri, options = nil)
      @last_status = 0

      @have_curl = Curl rescue nil
      if options && options.has_key?(:curl) && !options[:curl]
        @have_curl = false
      end
      @uri = uri
      @uri = URI.parse(@uri) if @uri.is_a? String
      @handler = @have_curl ? CurlHandler.new(@uri) : NetHttpHandler.new(@uri)
      @headers = options && options[:headers] ? options[:headers] : {}
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
    def start(&block) # :yield: dav
      @handler.start do
        return yield(self)
      end
    end

    # Set credentials for basic authentication
    def credentials(user, pass)
      @handler.user = user
      @handler.pass = pass
    end

    # Set extra headers for the dav request
    def headers(headers)
      @headers = headers
    end
    
    # Perform a PROPFIND request
    #
    # Example:
    #
    # Basic propfind:
    #
    #   properties = propfind('/path/')
    #
    # Get ACL for resource:
    #
    #  properties = propfind('/path/', :acl)
    #
    # Custom propfind:
    #
    #  properties = propfind('/path/', '<?xml version="1.0" encoding="utf-8"?>...')
    #
    # See http://webdav.org/specs/rfc3744.html#rfc.section.5.9 for more on
    # how to retrieve access control properties.
    def propfind(path,*options)
      headers = {'Depth' => '1'}
      acl_body = '<?xml version="1.0" encoding="utf-8" ?><D:propfind xmlns:D="DAV:"><D:prop><D:owner/>' +
              '<D:supported-privilege-set/><D:current-user-privilege-set/><D:acl/></D:prop></D:propfind>'
      if options.size == 1
        if (options[0] == :acl)
          body = acl_body
        else
          body = options[0]
        end
      elsif options.size == 2
        body = options[0]
        if options[1].is_a? Hash
          opts = options[1]
          headers['Depth'] = opts[:depth] if opts.include? :depth
        end
      end
      if(!body)
        body = '<?xml version="1.0" encoding="utf-8"?><DAV:propfind xmlns:DAV="DAV:"><DAV:allprop/></DAV:propfind>'
      end
      res = @handler.request(:propfind, path, body, headers.merge(@headers))
      Nokogiri::XML.parse(res.body)
    end

    # Find files and directories, yields Net::DAV::Item
    #
    # The :filename option can be a regexp or string, and is used
    # to filter the yielded items.
    #
    # If :suppress_errors is passed, exceptions that occurs when
    # reading directory information is ignored, and a warning is
    # printed out stderr instead.
    #
    # The default is to not traverse recursively, unless the :recursive
    # options is passed.
    #
    # Examples:
    #
    #  res = Net::DAV.start(url) do |dav|
    #    dav.find(url.path, :recursive => true) do |item|
    #      puts "#{item.type} #{item.uri}"
    #      puts item.content
    #    end
    #  end
    #
    #  dav = Net::DAV.new(url)
    #  dav.find(url.path, :filename => /\.html/, :suppress_errors => true)
    #    puts item.url.to_s
    #  end
    def find(path, options = {})
      path = @uri.merge(path).path
      namespaces = {'x' => "DAV:"}
      begin
        doc = propfind(path)
      rescue Net::ProtocolError => e
        msg = e.to_s + ": " + path.to_s
        if(options[:suppress_errors])then
          # Ignore dir if propfind returns an error
          warn("Warning: " + msg)
          return nil
        else
          raise e.class.new(msg, nil)
        end
      end
      path.sub!(/\/$/, '')
      doc./('.//x:response', namespaces).each do |item|
        uri = @uri.merge(item.xpath("x:href", namespaces).inner_text)
        size = item.%(".//x:getcontentlength", namespaces).inner_text rescue nil
        type = item.%(".//x:collection", namespaces) ? :directory : :file
        res = Item.new(self, uri, type, size, item)
        if type == :file then

          if(options[:filename])then
            search_term = options[:filename]
            filename = File.basename(uri.path)
            if(search_term.class == Regexp and search_term.match(filename))then
              yield res
            elsif(search_term.class == String and search_term == filename)then
              yield res
            end
          else
            yield res
          end

        elsif uri.path == path || uri.path == path + "/"
          # This is the top-level dir, skip it
        elsif options[:recursive] && type == :directory

          if(!options[:filename])then
            yield res
          end

          # This is a subdir, recurse
          find(uri.path, options) do |sub_res|
            yield sub_res
          end
        else
          if(!options[:filename])then
            yield res
          end
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
      path = @uri.merge(path).path
      body = @handler.request_returning_body(:get, path, @headers, &block)
      body
    end

    # Stores the content of a stream to a URL
    #
    # Example:
    # File.open(file, "r") do |stream|
    #   dav.put(url.path, stream, File.size(file))
    # end
    def put(path, stream, length)
      path = @uri.merge(path).path
      res = @handler.request_sending_stream(:put, path, stream, length, @headers)
      res.body
    end

    # Stores the content of a string to a URL
    #
    # Example:
    #   dav.put(url.path, "hello world")
    #
    def put_string(path, str)
      path = @uri.merge(path).path
      res = @handler.request_sending_body(:put, path, str, @headers)
      res.body
    end

    # Delete request
    #
    # Example:
    #   dav.delete(uri.path)
    def delete(path)
      path = @uri.merge(path).path
      res = @handler.request(:delete, path, nil, @headers)
      res.body
    end

    # Send a move request to the server.
    #
    # Example:
    #   dav.move(original_path, new_path)
    def move(path,destination)
      path = @uri.merge(path).path
      destination = @uri.merge(destination).to_s
      headers = {'Destination' => destination}
      res = @handler.request(:move, path, nil, headers.merge(@headers))
      res.body
    end

    # Send a copy request to the server.
    #
    # Example:
    #   dav.copy(original_path, destination)
    def copy(path,destination)
      path = @uri.merge(path).path
      destination = @uri.merge(destination).to_s
      headers = {'Destination' => destination}
      res = @handler.request(:copy, path, nil, headers.merge(@headers))
      res.body
    end

    # Do a proppatch request to the server to
    # update properties on resources or collections.
    #
    # Example:
    #   dav.proppatch(uri.path,
    #     "<d:set><d:prop>" +
    #     "<d:creationdate>#{new_date}</d:creationdate>" +
    #     "</d:set></d:prop>" +
    #     )
    def proppatch(path, xml_snippet)
      path = @uri.merge(path).path
      headers = {'Depth' => '1'}
      body =  '<?xml version="1.0"?>' +
      '<d:propertyupdate xmlns:d="DAV:">' +
         xml_snippet +
      '</d:propertyupdate>'
      res = @handler.request(:proppatch, path, body, headers.merge(@headers))
      Nokogiri::XML.parse(res.body)
    end

    # Send a lock request to the server
    #
    # On success returns an XML response body with a Lock-Token
    #
    # Example:
    #   dav.lock(uri.path, "<d:lockscope><d:exclusive/></d:lockscope><d:locktype><d:write/></d:locktype><d:owner>Owner</d:owner>")
    def lock(path, xml_snippet)
      path = @uri.merge(path).path
      headers = {'Depth' => '1'}
      body =  '<?xml version="1.0"?>' +
      '<d:lockinfo xmlns:d="DAV:">' +
         xml_snippet +
      '</d:lockinfo>'
      res = @handler.request(:lock, path, body, headers.merge(@headers))
      Nokogiri::XML.parse(res.body)
    end

    # Send an unlock request to the server
    #
    # Example:
    #   dav.unlock(uri.path, "opaquelocktoken:eee47ade-09ac-626b-02f7-e354175d984e")
    def unlock(path, locktoken)
     headers = {'Lock-Token' => '<'+locktoken+'>'}
     path = @uri.merge(path).path
     res = @handler.request(:unlock, path, nil, headers.merge(@headers))
    end

    # Returns true if resource exists on server.
    #
    # Example:
    #   dav.exists?('https://www.example.com/collection/')  => true
    #   dav.exists?('/collection/')  => true
    def exists?(path)
      path = @uri.merge(path).path
      headers = {'Depth' => '1'}
      body = '<?xml version="1.0" encoding="utf-8"?><DAV:propfind xmlns:DAV="DAV:"><DAV:allprop/></DAV:propfind>'
      begin
        res = @handler.request(:propfind, path, body, headers.merge(@headers))
      rescue
        return false
      end
      return (res.is_a? Net::HTTPSuccess)
    end

    # Makes a new directory (collection)
    def mkdir(path)
      path = @uri.merge(path).path
      res = @handler.request(:mkcol, path, nil, @headers)
      res.body
    end

    def verify_callback=(callback)
      @handler.verify_callback = callback
    end

    def verify_server=(value)
      @handler.verify_server = value
    end

  end
end
