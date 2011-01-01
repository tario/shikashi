=begin

This file is part of the shikashi project, http://github.com/tario/shikashi

Copyright (c) 2009-2010 Roberto Dario Seminara <robertodarioseminara@gmail.com>

shikashi is free software: you can redistribute it and/or modify
it under the terms of the gnu general public license as published by
the free software foundation, either version 3 of the license, or
(at your option) any later version.

shikashi is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.  see the
gnu general public license for more details.

you should have received a copy of the gnu general public license
along with shikashi.  if not, see <http://www.gnu.org/licenses/>.

=end
require "test/unit"
require "shikashi"

class TimeoutTest <  Test::Unit::TestCase

  def _test_timeout(execution_delay, timeout)
    priv = Shikashi::Privileges.new
    # allow the execution of the method sleep to emulate an execution delay
    priv.allow_method :sleep

    if execution_delay > timeout
      assert_raise Shikashi::Timeout::Error do
        # specify the timeout and the current binding to use the execution_delay parameter
        Shikashi::Sandbox.new.run("sleep execution_delay", priv, binding, :timeout => timeout)
      end
    else
      assert_nothing_raised do
        Shikashi::Sandbox.new.run("sleep execution_delay", priv, binding, :timeout => timeout)
      end
    end
  end

  def self.add_test(name, execution_delay, timeout)
    define_method("test_"+name)  do
      _test_timeout(execution_delay, timeout)
    end
  end

  add_test "basic",2,1
  add_test "float",0.2,0.1
  add_test "float_no_hit",0.1,0.2
  add_test "zero", 1,0
  add_test "zero_no_hit", 0,1

end

