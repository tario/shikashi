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
      Sandbox.new.run "x.foo", binding, :no_base_namespace => true
    }.should raise_error(SecurityError)

  end

  it "should not raise anything when call method with privileges" do

    x = X.new
    privileges = Privileges.new
    def privileges.allow?(*args)
      true
    end

    Sandbox.new.run "x.foo", binding, :privileges => privileges, :no_base_namespace => true

  end


  module A
    module B
      module C

      end
    end
  end

  it "should allow use a class declared inside" do
    priv = Privileges.new
    priv.allow_method :new
    Sandbox.new.run("
      class TestInsideClass
        def foo
        end
      end

      TestInsideClass.new.foo
    ", priv)
  end

  it "should use base namespace when the code uses colon3 node (2 levels)" do
    Sandbox.new.run( "::B",
        :base_namespace => A
    ).should be == A::B
  end

  it "should change base namespace when classes are declared (2 levels)" do
    Sandbox.new.run( "
                class ::X
                   def foo
                   end
                end
            ",
        :base_namespace => A
    )

    A::X
  end

  it "should use base namespace when the code uses colon3 node (3 levels)" do
    Sandbox.new.run( "::C",
        :base_namespace => A::B
    ).should be == A::B::C
  end

  it "should change base namespace when classes are declared (3 levels)" do
    Sandbox.new.run( "
                class ::X
                   def foo
                   end
                end
            ",
        :base_namespace => A::B
    )

    A::B::X
  end

  it "should reach local variables when current binding is used" do
    a = 5
    Sandbox.new.run("a", binding, :no_base_namespace => true).should be == 5
  end

  class N
    def foo
      @a = 5
      Sandbox.new.run("@a", binding, :no_base_namespace => true)
    end
  end


  it "should allow reference to instance variables" do
     N.new.foo.should be == 5
  end

  it "should create a default module for each sandbox" do
     s = Sandbox.new
     s.run('class X
              def foo
                 "foo inside sandbox"
              end
            end')

     x = s.base_namespace::X.new
     x.foo.should be == "foo inside sandbox"
  end

  it "should not allow xstr when no authorized" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("%x[echo hello world]", priv)
    }.should raise_error(SecurityError)

  end

  it "should allow xstr when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_xstr

    lambda {
      s.run("%x[echo hello world]", priv)
    }.should_not raise_error

  end

  it "should not allow global variable read" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("$a", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow global variable read when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_global_read(:$a)

    lambda {
      s.run("$a", priv)
    }.should_not raise_error
  end

  it "should not allow constant variable read" do
    s = Sandbox.new
    priv = Privileges.new

    TESTCONSTANT9999 = 9999
    lambda {
      s.run("TESTCONSTANT9999", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow constant read when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_read("TESTCONSTANT9998")
    TESTCONSTANT9998 = 9998

    lambda {
      s.run("TESTCONSTANT9998", priv).should be == 9998
    }.should_not raise_error
  end

  it "should allow read constant nested on classes when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_read("Fixnum")
    Fixnum::TESTCONSTANT9997 = 9997

    lambda {
      s.run("Fixnum::TESTCONSTANT9997", priv).should be == 9997
    }.should_not raise_error
  end


  it "should not allow global variable write" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("$a = 9", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow global variable write when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_global_write(:$a)

    lambda {
      s.run("$a = 9", priv)
    }.should_not raise_error
  end

  it "should not allow constant write" do
    s = Sandbox.new
    priv = Privileges.new

    lambda {
      s.run("TESTCONSTANT9999 = 99991", priv)
    }.should raise_error(SecurityError)
  end

  it "should allow constant write when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_write("TESTCONSTANT9998")

    lambda {
      s.run("TESTCONSTANT9998 = 99981", priv)
      TESTCONSTANT9998.should be == 99981
    }.should_not raise_error
  end

  it "should allow write constant nested on classes when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_const_read("Fixnum")
    priv.allow_const_write("Fixnum::TESTCONSTANT9997")

    lambda {
      s.run("Fixnum::TESTCONSTANT9997 = 99971", priv)
      Fixnum::TESTCONSTANT9997.should be == 99971
    }.should_not raise_error
  end


end
