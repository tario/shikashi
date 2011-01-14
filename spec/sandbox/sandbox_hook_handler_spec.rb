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

  class X
    def foo

    end
  end
  it "should raise SecurityError when handle calls without privileges" do
    sandbox = Sandbox.new
    hook_handler = sandbox.create_hook_handler()

    x = X.new
    lambda {
      hook_handler.handle_method(X,x,:foo)
    }.should raise_error(SecurityError)

  end


end