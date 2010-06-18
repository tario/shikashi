# "hello world" from within the sandbox

require "rubygems"
require "shikashi"

include Shikashi

s = Sandbox.new
priv = Privileges.new
priv.allow_method :print

s.run(priv, 'print "hello world\n"')
