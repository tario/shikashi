require "rubygems"
require "shikashi"

include Shikashi

describe Sandbox, "Shikashi sandbox" do
  it "should run empty code without privileges" do
    Sandbox.new.run ""
  end

  it "should run empty code with privileges" do
    Sandbox.new.run "", Privileges.new
  end

  class X
    def foo
    end
  end
  it "should raise SecurityError when call method without privileges" do

    x = X.new

    lambda {
      Sandbox.new.run "x.foo", binding
    }.should raise_error(SecurityError)

  end

  it "should not raise anything when call method with privileges" do

    x = X.new
    privileges = Privileges.new
    def privileges.allow?(*args)
      true
    end

    Sandbox.new.run "x.foo", binding, :privileges => privileges

  end

end
