require "shikashi"

describe Sandbox, "Shikashi sandbox" do
  it "should allow single run" do
    Sandbox.run("0").should be == 0
  end

  it "should allow single run with empty privileges" do
    priv = Privileges.new
    Sandbox.run("0", priv).should be == 0
  end

  it "should allow single run with privileges allowing + method (as symbol)" do
    priv = Privileges.new
    priv.allow_method :+
    Sandbox.run("1+1", priv).should be == 2
  end

  it "should allow single run with privileges allowing + method (as string)" do
    priv = Privileges.new
    priv.allow_method "+"
    Sandbox.run("1+1", priv).should be == 2
  end

  it "should allow single run with privileges using sugar syntax and allowing + method (as symbol)" do
    Sandbox.run("1+1", Privileges.allow_method(:+)).should be == 2
  end

  it "should allow single run with privileges using sugar syntax and allowing + method (as string)" do
    Sandbox.run("1+1", Privileges.allow_method("+")).should be == 2
  end

end

