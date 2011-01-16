# define a class from inside the sandbox and use it from outside

require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new

# allow execution of print
priv.allow_method :print

# allow definition of classes
priv.allow_class_definitions

#inside the sandbox, only can use method foo on main and method times on instances of Fixnum
s.run(priv, '
class X
	def foo
		print "X#foo\n"
	end
	
	def bar
		system("ls -l")
	end
end
')

# run privileged code in the sandbox, if not, the methods defined in the sandbox are invisible from outside
x = s.base_namespace::X.new
x.foo
begin
	x.bar
rescue SecurityError => e
	print "x.bar failed due security errors: #{e}\n"
end

