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
require "shikashi/object_wrapper"

module Shikashi
#
#The Privileges class represent permissions about methods and objects
#
class Privileges

private
  def self.load_privilege_packages
    Find.find(__FILE__.split("/")[0..-2].join("/") + "/privileges" ) do |path|
      if path =~ /\.rb$/
        require path
      end
    end
  end

  load_privilege_packages
public
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
    @allowed_instances = Hash.new
    @allowed_methods = Array.new
    @allowed_klass_methods = Hash.new
  end

private
  def hash_entry(hash, key)
    tmp = hash[key]
    unless tmp
      tmp = AllowedMethods.new
      hash[key] = tmp
    end
    tmp
  end
public

#
#Specifies the methods allowed for an specific object
#
#Example 1:
# privileges.object(Hash).allow :new
#

  def object(obj)
    hash_entry(@allowed_objects, obj.object_id)
  end

#
#Specifies the methods allowed for the instances of a class
#
#Example 1:
# privileges.instances_of(Array).allow :each # allow calls of methods named "each" over instances of Array
#
#Example 2:
# privileges.instances_of(Array).allow :select, map # allow calls of methods named "each" and "map" over instances of Array
#
#Example 3:
# privileges.instances_of(Hash).allow_all # allow any method call over instances of Hash
#
  def instances_of(klass)
    hash_entry(@allowed_instances, klass.object_id)
  end

#
#Specifies the methods allowed for an implementation in specific class
#
#Example 1:
# privileges.methods_of(X).allow :foo
#
# ...
# class X
#   def foo # allowed :)
#   end
# end
#
# class Y < X
#   def foo # disallowed
#   end
# end
#
# X.new.foo # allowed
# Y.new.foo # disallowed: SecurityError
# ...
#
  def methods_of(klass)
    hash_entry(@allowed_klass_methods, klass.object_id)
  end

#allow the execution of method named method_name whereever
#
#Example:
# privileges.allow_method(:foo)
#

  def allow_method(method_name)
    @allowed_methods << method_name
  end

  def allow?(klass, recv_, method_name, method_id)

    recv = ObjectWrapper.new(recv_)
    m = nil
    m = recv.method(method_name) if method_name

    begin
      return true if @allowed_methods.include?(method_name)

      tmp = @allowed_objects[recv.object_id]
      if tmp
        if tmp.allowed?(method_name)
          return true
        end
      end

      if m
        tmp = @allowed_klass_methods[m.owner.object_id]
        if tmp
          if tmp.allowed?(method_name)
            return true
          end
        end
      end

      if recv.instance_of? Class
        last_class = recv

        while true
          tmp = @allowed_classes[last_class.object_id]
          if tmp
            if tmp.allowed?(method_name)
              return true
            end
          end
          if last_class
            break if last_class == Object
            last_class = last_class.superclass
          else
            break
          end
        end
      end

      last_class = recv.class
      while true
        tmp = @allowed_kinds[last_class.object_id]
        if tmp
          if tmp.allowed?(method_name)
            return true
          end
        end
        if last_class
          break if last_class == Object
          last_class = last_class.superclass
        else
          break
        end
      end

      tmp = @allowed_instances[recv.class.object_id]
      if tmp
        if tmp.allowed?(method_name)
          return true
        end
      end

      false
    rescue Exception => e
      print "ERROR: #{e}\n"
    print e.backtrace.join("\n")
      false
    end
  end
end

end

