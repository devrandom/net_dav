module Net
  class DAV
    # Hold items found using Net::DAV#find
    class Item
      # URI of item
      attr_reader :uri

      # Size of item if a file
      attr_reader :size

      # Type of item - :directory or :file
      attr_reader :type

      # Synonym for uri
      def url
	@uri
      end

      def initialize(dav, uri, type, size) #:nodoc:
	@uri = uri
	@size = size
	@type = type
	@dav = dav
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

      def to_s #:nodoc:
	"#<Net::DAV::Item URL:#{@uri.to_s} type:#{@type}>"
      end

      def inspect #:nodoc:
	"#<Net::DAV::Item URL:#{@uri.to_s} type:#{@type}>"
      end
    end
  end
end
