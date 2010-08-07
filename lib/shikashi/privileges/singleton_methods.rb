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
  class Privileges
    #Define the permissions needed to define singleton methods within the sandbox
    def allow_singleton_methods
      allow_method :singleton_method_added
      allow_method "core#define_singleton_method".to_sym
    end
  end
end
