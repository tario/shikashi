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
require "find"

module Shikashi
#
#The Privileges class represent permissions about methods and objects
#
class Privileges

  def self.load_privilege_packages
    Find.find(__FILE__.split("/")[0..-2].join("/") + "/privileges" ) do |path|
      if path =~ /\.rb$/
        require path
      end
    end
  end

  load_privilege_packages

  class AllowedMethods
    def initialize
      @allowed_methods = Array.new
      @all = false
    end

    def allowed?(mn)
       if @all
         true
       else
         @allowed_methods.include?(mn)
       end
    end

    def allow(*mns)
      mns.each do |mn|
      @allowed_methods << mn
      end
    end

    def allow_all
      @all = true
    end
  end

  def initialize
    @allowed_objects = Hash.new
    @allowed_kinds = Hash.new
    @allowed_classes = Hash.new
    @allowed_methods = Array.new
  end

  def object(obj)
    tmp = nil
    unless @allowed_objects[obj.__id__]
      tmp = AllowedMethods.new
      @allowed_objects[obj.__id__] = tmp
    end
    tmp
  end

  def kind_of(klass)
    tmp = nil
    unless @allowed_kinds[klass.__id__]
      tmp = AllowedMethods.new
      @allowed_kinds[klass.__id__] = tmp
    end
    tmp
  end

  def class_inherited_of(klass)
    tmp = nil
    unless @allowed_classes[klass.__id__]
      tmp = AllowedMethods.new
      @allowed_classes[klass.__id__] = tmp
    end
    tmp
  end
  # allow the execution of method named method_name whereever
  def allow_method(method_name)
    @allowed_methods << method_name
  end

  def allow?(klass, recv, method_name, method_id)

    begin

      return true if @allowed_methods.include?(method_name)

      tmp = @allowed_objects[recv.__id__]
      if tmp
        if tmp.allowed?(method_name)
          return true
        end
      end

      if recv.instance_of? Class
        last_class = recv
        while true
          tmp = @allowed_classes[last_class.__id__]
          if tmp
            if tmp.allowed?(method_name)
              return true
            end
          end
          last_class = last_class.superclass
          break if last_class == Object
        end
      end


      last_class = recv.class
      while true
        tmp = @allowed_kinds[last_class.__id__]
        if tmp
          if tmp.allowed?(method_name)
            return true
          end
        end
        last_class = last_class.superclass
        break if last_class == Object
      end


      false
    rescue Exception => e
#      print "ERROR: #{e}\n"
 #     print e.backtrace.join("\n")
      false
    end
  end
end

end