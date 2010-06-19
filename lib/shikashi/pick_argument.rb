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
module Arguments
  module NoDefault
  end
end
class Array

  def pick_by_class(klass)
    klassary = self.select{|x| x.instance_of? klass}
    if klassary.size > 1
      raise ArgumentError, "ambiguous parameters of class #{klass}"
    elsif klassary.size == 1
      klassary.first
    else
      nil
    end

  end

  def pick(*args)

    klass = args.pick_by_class Class
    hash_key = args.pick_by_class Symbol

    ary = []

    if klass
      ary = self.select{|x| x.instance_of? klass}

      if ary.size > 1
        raise ArgumentError, "ambiguous parameters of class #{klass}"
      end
    else
      ary = []
    end

    if hash_key
      each do |x|
        if x.instance_of? Hash
          if x[hash_key]
            ary << x[hash_key]
          end
        end
      end

      if ary.size > 1
        raise ArgumentError, "ambiguous parameters of class #{klass} and key '#{hash_key}'"
      end

    end

    if ary.size == 1
      return ary.first
    end

    unless block_given?
      raise ArgumentError, "missing mandatory argument '#{hash_key}' or of class #{klass}"
    end

    yield
  end
end