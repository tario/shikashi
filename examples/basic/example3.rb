# define a class outside the sandbox and use it in the sandbox

require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new

# allow execution of print
priv.allow_method :print

class X
	def foo
		print "X#foo\n"
	end
	
	def bar
		system("echo hello world") # accepted, called from privileged context
	end
	
	def privileged_operation( out )
		# write to file specified in out
		system("echo privileged operation > " + out)
	end
end
# allow method new of class X
priv.object(X).allow :new

# allow instance methods of X. Note that the method privileged_operations is not allowed
priv.instances_of(X).allow :foo, :bar

#inside the sandbox, only can use method foo on main and method times on instances of Fixnum
s.run(priv, '
x = X.new
x.foo
x.bar

begin
x.privileged_operation # FAIL
rescue SecurityError
print "privileged_operation failed due security error\n"
end
')
