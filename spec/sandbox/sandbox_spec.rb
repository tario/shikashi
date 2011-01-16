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

  it "should use default binding when is not specified in the arguments and reach local variables" do
    a = 5
    Sandbox.new.run("a", :no_base_namespace => true).should be == 5
  end

  class N
    def foo
      @a = 5
      Sandbox.new.run("@a", :no_base_namespace => true)
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

  it "should allow xstr when authorized" do
    s = Sandbox.new
    priv = Privileges.new

    priv.allow_xstr

    lambda {
      s.run("%x[echo hello world]", priv)
    }.should_not raise_error

  end


end
