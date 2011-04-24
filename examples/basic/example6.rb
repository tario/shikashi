# "hello world" from within the sandbox

require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new

priv.allow_method :print
priv.allow_global_write :$a

s.run(priv, '
$a = 9
print "assigned 9 to $a\n"
')

p $a
