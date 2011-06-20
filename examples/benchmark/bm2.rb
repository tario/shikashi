require "rubygems"
require "shikashi"
require "benchmark"

s = Shikashi::Sandbox.new

Benchmark.bm(7) do |x|

x.report {

	code = "
		class X
			def foo(n)
			end
		end
		
		x = X.new
		500000.times {
		x.foo(1000)
		}
		"
		
	s.run code, Shikashi::Privileges.allow_method(:times).allow_method(:new)
}

end
