require "rubygems"
require "shikashi"
require "evalhook"

include Shikashi

describe Sandbox, "Shikashi sandbox hook handler" do

  it "should be obtainable from sandbox" do
    Sandbox.new.hook_handler
  end

  it "should be obtainable from sandbox through create_hook_handler" do
    sandbox = Sandbox.new
    hook_handler = sandbox.create_hook_handler()
    hook_handler.should be_kind_of(EvalHook::HookHandler)
  end

end