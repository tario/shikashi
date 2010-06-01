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

module Shikashi
#
#Wraps an object and make all the calls using the implementation of the class Object
#regardless of if the method are overloaded or not
#
#Example:
#
# class X
#   def instance_of?(a)
#     return true
#   end
#   def foo
#   end
# end
#
# x = X.new
# x.instance_of?(Fixnum)  # fake instance_of? return true
# x.instance_of?(X)  # fake instance_of? return true
#
# x.foo   # normal
#
# xw = ObjectWrapper.new(x)
# xw.instance_of?(Fixnum) # real instance_of? of the class Object return false, the right value
# xw.instance_of?(X) # real instance_of? of the class Object return true, the right value
#
# xw.foo # NoMethodError, the wrapper doesn't work for methods that are not defined in the Object class
#
  class ObjectWrapper

    instance_methods.each do |str|
      if (str != "__send__" and str != "__id__")
        undef_method str.to_sym
      end
    end

    def initialize(obj)
      @obj = obj
    end

    def method_missing(m, *args)
      Object.instance_method(m).bind(@obj).call(*args)
    end

    def superclass(*args)
      Class.instance_method(:superclass).bind(@obj).call(*args)
    end
  end
end