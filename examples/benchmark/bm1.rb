require "rubygems"
require "shikashi"
require "benchmark"

code = "class X
		def foo(n)
		end
	end
	X.new.foo(1000)
	"

s = Shikashi::Sandbox.new

Benchmark.bm(7) do |x|
	
x.report("normal") {
	1000.times do
	s.run(code, Shikashi::Privileges.allow_method(:new))
	end
}

x.report("packet") {
	packet = s.packet(code, Shikashi::Privileges.allow_method(:new))
	1000.times do
	packet.run
	end
}

end