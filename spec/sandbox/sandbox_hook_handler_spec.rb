require "rubygems"
require "shikashi"

include Shikashi

describe Sandbox, "Shikashi sandbox hook handler" do

  it "should be obtainable from sandbox" do
    Sandbox.new.hook_handler
  end

end