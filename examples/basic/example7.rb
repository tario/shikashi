require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new

priv.allow_method :print
priv.allow_const "Object::A"

s.run(priv, '
print "assigned 8 to Object::A\n"
A = 8
')
p A

