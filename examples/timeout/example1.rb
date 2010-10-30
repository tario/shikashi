	require "rubygems"
	require "shikashi"

	s = Shikashi::Sandbox.new
	perm = Shikashi::Privileges.new

	perm.allow_method :sleep

	s.run(perm,"sleep 3", :timeout => 2) # raise Shikashi::Timeout::Error after 2 seconds
