#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'rubygems'
require 'webrick'
require 'webrick/httpservlet/webdavhandler'

# Webdav server based on:
# http://github.com/aslakhellesoy/webdavjs/blob/master/spec/webdav_server.rb


# Monkey patch REXML to always nil-indent. The indentation is broken in REXML
# on Ruby 1.8.6 and even when fixed it confuses OS-X.
module REXML
  module Node
    alias old_to_s to_s
    def to_s(indent=nil)
      old_to_s(nil)
    end
  end
end

# http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/223386
# http://gmarrone.objectblues.net/cgi-bin/wiki/WebDAV_-_Linux_server%2c_Mac_OS_X_client
module WEBrick
  module HTTPServlet
    class WebDAVHandlerVersion2 < WebDAVHandler

      def do_OPTIONS(req, res)
        super
        res["DAV"] = "1,2"
      end

      def do_LOCK(req, res)
        res.body << "<XXX-#{Time.now.to_s}/>"
      end

    end

    class WebDAVHandlerVersion3 < WebDAVHandlerVersion2

      # Enable authentication
      $REALM = "WebDav share"
      $USER = "myuser"
      $PASS = "mypass"

      def service(req, res)
        HTTPAuth.basic_auth(req, res, $REALM) {|user, pass|
          # this block returns true if
          # authentication token is valid
          user == $USER && pass == $PASS
        }
        super
      end

    end

  end
end

def webdav_server(*options)
  port = 10080
  if(options and options[0][:port])
    port = options[0][:port]
  end
  log = WEBrick::Log.new
  log.level = WEBrick::Log::DEBUG if $DEBUG
  serv = WEBrick::HTTPServer.new({:Port => port, :Logger => log})


  dir = Dir.pwd + '/spec/fixtures'
  if(options and options[0][:authentication])
    serv.mount("/", WEBrick::HTTPServlet::WebDAVHandlerVersion3, dir)
  else
    serv.mount("/", WEBrick::HTTPServlet::WebDAVHandlerVersion2, dir)
  end


  trap(:INT){ serv.shutdown }
  serv.start
end

if($0 ==  __FILE__)
  webdav_server(:port => 10080,:authentication => false)
end
