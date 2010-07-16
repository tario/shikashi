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
      assert_not_raise do
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

