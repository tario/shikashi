# "hello world" from within the sandbox

require "rubygems"
require "shikashi"

include Shikashi

priv = Privileges.allow_method(:print).allow_global_write(:$a)
Sandbox.run(priv,
'
$a = 9
print "assigned 9 to $a\n"
'
)

p $a
