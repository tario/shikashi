require "rubygems"
require "shikashi"

include Shikashi

priv = Privileges.
	allow_method(:print).
	allow_const_write("Object::A")

Sandbox.run(priv, '
print "assigned 8 to Object::A\n"
A = 8
')
p A

