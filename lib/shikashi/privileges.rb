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

  # Used in Privileges to store information about specified method permissions
  class AllowedMethods
    def initialize(privileges = nil)
      @privileges = privileges
      @allowed_methods = Array.new
      @redirect_hash = Hash.new
      @all = false
    end

    #return true if the method named method_name is allowed
    #Example
    #
    # allowed_methods = AllowedMethods.new
    # allowed_methods.allowed? :foo # => false
    # allowed_methods.allow :foo
    # allowed_methods.allowed? :foo # => true
    # allowed_methods.allow_all
    # allowed_methods.allowed? :bar # => true
    #
    # Privileges#instance_of, Privileges#methods_of and Privileges#object returns the corresponding
    # instance of AllowedMethods
    def allowed?(method_name)
       if @all
         true
       else
         @allowed_methods.include?(method_name)
       end
    end

    #Specifies that a method or list of methods are allowed
    #Example
    #
    # allowed_methods = AllowedMethods.new
    # allowed_methods.allow :foo
    # allowed_methods.allow :foo, :bar
    # allowed_methods.allow :foo, :bar, :test
    #
    def allow(*method_names)
      method_names.each do |mn|
      @allowed_methods << mn
      end

      @privileges
    end

    #Specifies that any method is allowed
    def allow_all
      @all = true

      @privileges
    end

  end

  def initialize
    @allowed_objects = Hash.new
    @allowed_kinds = Hash.new
    @allowed_classes = Hash.new
    @allowed_instances = Hash.new
    @allowed_methods = Array.new
    @allowed_klass_methods = Hash.new
    @allowed_read_globals = Array.new
    @allowed_read_consts = Array.new
    @allowed_write_globals = Array.new
    @allowed_write_consts = Array.new
  end

private
  def hash_entry(hash, key)
    tmp = hash[key]
    unless tmp
      tmp = AllowedMethods.new(self)
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
    @allowed_methods << method_name.to_sym
    self
  end

  def allow?(klass, recv, method_name, method_id)

    m = nil
    m = klass.instance_method(method_name) if method_name

    begin
      return true if @allowed_methods.include?(method_name)

      tmp = @allowed_objects[recv.object_id]
      if tmp
        if tmp.allowed?(method_name)
          @last_allowed = tmp
          return true
        end
      end

      if m
        tmp = @allowed_klass_methods[m.owner.object_id]
        if tmp
          if tmp.allowed?(method_name)
            @last_allowed = tmp
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
              @last_allowed = tmp
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
            @last_allowed = tmp
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
        @last_allowed = tmp
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

  def xstr_allowed?
    @xstr_allowed
  end

  def global_read_allowed?(varname)
    @allowed_read_globals.include? varname
  end

  def global_write_allowed?(varname)
    @allowed_write_globals.include? varname
  end

  def const_read_allowed?(varname)
    @allowed_read_consts.include? varname
  end

  def const_write_allowed?(varname)
    @allowed_write_consts.include? varname
  end

  # Enables the permissions needed to execute system calls from the script
  #
  # Example:
  #
  #   s = Sandbox.new
  #   priv = Privileges.new
  #
  #   priv.allow_xstr
  #
  #   s.run(priv, '
  #     %x[ls -l]
  #   ')
  #
  #
  # Example 2:
  #
  #   Sandbox.run('%x[ls -l]', Privileges.allow_xstr)
  #
  def allow_xstr
    @xstr_allowed = true

    self
  end

  # Enables the permissions needed to read one or more global variables
  #
  # Example:
  #
  #   s = Sandbox.new
  #   priv = Privileges.new
  #
  #   priv.allow_method :print
  #   priv.allow_global_read :$a
  #
  #   $a = 9
  #
  #   s.run(priv, '
  #   print "$a value:", $a, "s\n"
  #   ')
  #
  # Example 2
  #
  #   Sandbox.run('
  #   print "$a value:", $a, "s\n"
  #   print "$b value:", $b, "s\n"
  #   ', Privileges.allow_global_read(:$a,:$b) )
  #
  def allow_global_read( *varnames )
    varnames.each do |varname|
      @allowed_read_globals << varname.to_sym
    end

    self
  end

  # Enables the permissions needed to create or change one or more global variables
  #
  # Example:
  #
  #   s = Sandbox.new
  #   priv = Privileges.new
  #
  #   priv.allow_method :print
  #   priv.allow_global_write :$a
  #
  #   s.run(priv, '
  #   $a = 9
  #   print "assigned 9 to $a\n"
  #   ')
  #
  #   p $a
  #
  def allow_global_write( *varnames )
    varnames.each do |varname|
      @allowed_write_globals << varname.to_sym
    end

    self
  end


  # Enables the permissions needed to create or change one or more constants
  #
  # Example:
  #   s = Sandbox.new
  #   priv = Privileges.new
  #
  #   priv.allow_method :print
  #   priv.allow_const_write "Object::A"
  #
  #   s.run(priv, '
  #   print "assigned 8 to Object::A\n"
  #   A = 8
  #   ')
  #
  #   p A

  def allow_const_write( *varnames )
    varnames.each do |varname|
      @allowed_write_consts << varname.to_s
    end
    self
  end

  # Enables the permissions needed to read one or more constants
  #
  # Example:
  #   s = Sandbox.new
  #   priv = Privileges.new
  #
  #   priv.allow_method :print
  #   priv.allow_const_read "Object::A"
  #
  #   A = 8
  #   s.run(priv, '
  #   print "assigned Object::A:", A,"\n"
  #   ')
  #
  def allow_const_read( *varnames )
    varnames.each do |varname|
      @allowed_read_consts << varname.to_s
    end

    self
  end


  class << self
    (Shikashi::Privileges.instance_methods - Object.instance_methods).each do |mname|
      define_method(mname) do |*args|
        Shikashi::Privileges.new.send(mname, *args)
      end
    end
  end
end

end

