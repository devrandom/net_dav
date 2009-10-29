require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Net::Dav" do
  it "should create a Net::Dav object" do
    Net::DAV.new("http://localhost.localdomain/").should_not be_nil
  end
end
