module Net
  class DAV
    # Hold items found using Net::DAV#find
    class Item

      # Hold <response> XML element and provides facilities to query attributes
      class Props

        # The <response> XML element
        attr_reader :response

        def initialize(response)
          @response = response
          @namespaces = {"x" => "DAV:"}
        end

        def displayname
          @response./(".//x:displayname", @namespaces).inner_text
        end

        def contenttype
          @response./(".//x:getcontenttype", @namespaces).inner_text rescue nil
        end

        def contentlength
          @response./(".//x:getcontentlength", @namespaces).inner_text rescue nil
        end

        def creationdate
          Time.parse(@response./(".//x:creationdate", @namespaces).inner_text)
        end

        def lastmodificationdate
          Time.parse(@response./(".//x:getlastmodified", @namespaces).inner_text)
        end

      end

      # URI of item
      attr_reader :uri

      # Size of item if a file
      attr_reader :size

      # Type of item - :directory or :file
      attr_reader :type

      # Properties holder
      attr_reader :properties

      # Synonym for uri
      def url
        @uri
      end

      def initialize(dav, uri, type, size, properties) #:nodoc:
        @uri = uri
        @size = size.to_i rescue nil
        @type = type
        @dav = dav
        @properties = Props.new(properties)
      end

      # Get content from server if needed and return as string
      def content
        return @content unless @content.nil?
        @content = @dav.get(@uri.path)
      end

      # Put content to server
      def content=(str)
        @dav.put_string(@uri.path, str)
        @content = str
      end

      # Proppatch item
      def proppatch(xml_snippet)
        @dav.proppatch(@uri.path,xml_snippet)
      end

      #Properties for this item
      def propfind
        return @dav.propfind(@uri.path)
      end

      def to_s #:nodoc:
        "#<Net::DAV::Item URL:#{@uri.to_s} type:#{@type}>"
      end

      def inspect #:nodoc:
        "#<Net::DAV::Item URL:#{@uri.to_s} type:#{@type}>"
      end
    end
  end
end
