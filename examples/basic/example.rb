# call method defined in sandbox from outside
require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new

priv.allow_method :singleton_method_added

# allow execution of foo in this object
priv.object(self).allow :foo

# allow execution of print in this object
priv.object(self).allow :print

#inside the sandbox, only can use method foo on main and method times on instances of Fixnum
code = "
def inside_foo(a)
	print 'inside_foo'
	if (a)
	system('ls -l') # denied
	end
end
"

s.run(code, priv)

inside_foo(false)
#inside_foo(true) #SecurityError
