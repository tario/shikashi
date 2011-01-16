# call method defined in sandbox from outside

require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new

# allow execution of print
priv.allow_method :print

#inside the sandbox, only can use method foo on main and method times on instances of Fixnum
s.run(priv, '
module A
def self.inside_foo(a)
	print "inside_foo\n"
	if (a)
	system("ls -l") # denied
	end
end
end
')

# run privileged code in the sandbox, if not, the methods defined in the sandbox are invisible from outside
s.base_namespace::A.inside_foo(false)
begin
	s.base_namespace::A.inside_foo(true)
rescue SecurityError => e
	print "A.inside_foo(true) failed due security errors: #{e}\n"
end

