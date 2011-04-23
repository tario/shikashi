require "shikashi"

include Shikashi

describe Privileges, "Shikashi::Privileges" do

  # method chaining
  it "allow_method should return object of Privileges class" do
    Privileges.allow_method(:foo).should be_kind_of(Privileges)
  end

  it "allow_global_read should return object of Privileges class" do
    Privileges.allow_global_read(:$a).should be_kind_of(Privileges)
  end

  it "allow_global_write should return object of Privileges class" do
    Privileges.allow_global_write(:$a).should be_kind_of(Privileges)
  end

  it "allow_const_read should return object of Privileges class" do
    Privileges.allow_const_read(:$a).should be_kind_of(Privileges)
  end

  it "allow_const_write should return object of Privileges class" do
    Privileges.allow_const_write(:$a).should be_kind_of(Privileges)
  end

  it "allow_xstr should return object of Privileges class" do
    Privileges.allow_xstr.should be_kind_of(Privileges)
  end

  it "instances_of(...).allow() should return object of Privileges class" do
    Privileges.instances_of(Fixnum).allow("foo").should be_kind_of(Privileges)
  end

  it "object(...).allow() should return object of Privileges class" do
    Privileges.object(Fixnum).allow("foo").should be_kind_of(Privileges)
  end

  it "methods_of(...).allow() should return object of Privileges class" do
    Privileges.methods_of(Fixnum).allow("foo").should be_kind_of(Privileges)
  end

  it "instances_of(...).allow() should return object of Privileges class" do
    Privileges.instances_of(Fixnum).allow_all.should be_kind_of(Privileges)
  end

  it "object(...).allow() should return object of Privileges class" do
    Privileges.object(Fixnum).allow_all.should be_kind_of(Privileges)
  end

  it "methods_of(...).allow() should return object of Privileges class" do
    Privileges.methods_of(Fixnum).allow_all.should be_kind_of(Privileges)
  end

  it "should chain one allow_method" do
    priv = Privileges.allow_method(:to_s)
    priv.allow?(Fixnum,4,:to_s,0).should be == true
  end

  it "should chain one allow_method and one allow_global" do
    priv = Privileges.
        allow_method(:to_s).
        allow_global_read(:$a)

    priv.allow?(Fixnum,4,:to_s,0).should be == true
    priv.global_read_allowed?(:$a).should be == true
  end

  # argument conversion
  it "should allow + method (as string)" do
    priv = Privileges.new
    priv.allow_method("+")
    priv.allow?(Fixnum,4,:+,0).should be == true
  end

  it "should allow + method (as symbol)" do
    priv = Privileges.new
    priv.allow_method(:+)
    priv.allow?(Fixnum,4,:+,0).should be == true
  end

  it "should allow $a global read (as string)" do
    priv = Privileges.new
    priv.allow_global_read("$a")
    priv.global_read_allowed?(:$a).should be == true
  end

  it "should allow $a global read (as symbol)" do
    priv = Privileges.new
    priv.allow_global_read(:$a)
    priv.global_read_allowed?(:$a).should be == true
  end

  it "should allow multiple global read (as symbol) in only one allow_global_read call" do
    priv = Privileges.new
    priv.allow_global_read(:$a, :$b)
    priv.global_read_allowed?(:$a).should be == true
    priv.global_read_allowed?(:$b).should be == true
  end

  it "should allow $a global write (as string)" do
    priv = Privileges.new
    priv.allow_global_write("$a")
    priv.global_write_allowed?(:$a).should be == true
  end

  it "should allow $a global write (as symbol)" do
    priv = Privileges.new
    priv.allow_global_write(:$a)
    priv.global_write_allowed?(:$a).should be == true
  end

  it "should allow multiple global write (as symbol) in only one allow_global_write call" do
    priv = Privileges.new
    priv.allow_global_write(:$a, :$b)
    priv.global_write_allowed?(:$a).should be == true
    priv.global_write_allowed?(:$b).should be == true
  end
end