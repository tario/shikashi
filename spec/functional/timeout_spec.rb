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

include Shikashi

describe Sandbox, "Shikashi sandbox" do

  def self.add_test(name, execution_delay, timeout)
    if execution_delay > timeout
      it "Should allow timeout of type #{name}" do
        priv = Shikashi::Privileges.new
        priv.allow_method :sleep

        lambda {
        Sandbox.new.run "sleep #{execution_delay}", priv, :timeout => timeout
        }.should raise_error(Shikashi::Timeout::Error)
      end
    else
      it "Should allow timeout of type #{name}" do
        priv = Shikashi::Privileges.new
        priv.allow_method :sleep

        Sandbox.new.run "sleep #{execution_delay}", priv, :timeout => timeout

      end

    end
  end

  add_test "basic",2,1
  add_test "float",0.2,0.1
  add_test "float_no_hit",0.1,0.2
  add_test "zero", 1,0
  add_test "zero_no_hit", 0,1

end

