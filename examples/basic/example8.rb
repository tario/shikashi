require "rubygems"
require "shikashi"

include Shikashi

module SandboxModule
end

class X
	def foo
		print "X#foo\n"
	end
end

s = Sandbox.new
priv = Privileges.new
priv.allow_method :print

s.run( "
  class ::X
	def foo
		print \"foo defined inside the sandbox\\n\"
	end
  end
  ", priv, :base_namespace => SandboxModule)
  

x = X.new # X class is not affected by the sandbox (The X Class defined in the sandbox is SandboxModule::X)
x.foo

x = SandboxModule::X.new
x.foo

