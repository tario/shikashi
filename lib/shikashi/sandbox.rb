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

require "rallhook"
require "shikashi/privileges"
require "shikashi/object_wrapper"

module Shikashi

  class << self
    attr_accessor :global_binding
  end


#The sandbox class run the sandbox, because of internal behaviour only can be use one instance
#of sandbox by thread (each different thread may have its own sandbox running in the same time)
#
#Example:
#
# require "shikashi"
#
# include Shikashi
#
# s = Sandbox.new
# priv = Privileges.new
# priv.allow_method :print
#
# s.run(priv, 'print "hello world\n"')
#
  class Sandbox

#array of privileges of restricted code within sandbox
#
#Example
# sandbox.privileges[source].allow_method :raise
#
    attr_reader :privileges
#Binding of execution, the default is a binding in a global context allowing the definition of module of classes
    attr_accessor :eval_binding
#Hash with the chains of sources
    attr_reader :chain

#
# Generate a random source file name for the sandbox, used internally
#

    def generate_id
      "sandbox-#{rand(1000000)}"
    end

    def initialize
      @privileges = Hash.new
      @chain = Hash.new
      self.eval_binding = Shikashi.global_binding
    end

# add a chain of sources, used internally
    def add_source_chain(outer, inner)
      @chain[inner] = outer
    end


#Base class to define redirections of methods called in the sandbox
#
#Example:
#
# require "shikashi"
#
# class TestWrapper < Shikashi::Sandbox::MethodWrapper
#   def call(*args)
#     print "called foo from source: #{source}, arguments: #{args.inspect} \n"
#     original_call(*args)
#   end
# end
#
#
# class X
#   def foo
#     print "original foo\n"
#   end
# end
#
#
# s = Shikashi::Sandbox.new
# perm = Shikashi::Privileges.new
#
# perm.object(X).allow :new
# perm.instances_of(X).allow :foo
#
# # redirect calls to foo to TestWrapper
# perm.instances_of(X).redirect :foo, TestWrapper
#
# s.run(perm,"X.new.foo")
#
    class MethodWrapper < RallHook::Helper::MethodWrapper
      attr_accessor :sandbox
      attr_accessor :privileges
      attr_accessor :source
      def objwrap(recv)
        ObjectWrapper.new(recv)
      end

      def inherited_check(args)
        if method_name == :inherited then
          if objwrap(recv).instance_of? Class then
            subclass = args.first
            sandbox.privileges.object(subclass).allow :new
            sandbox.privileges.instances_of(subclass).allow :initialize
          end
        end
      end

      def self.redirect_handler(klass,recv,method_name,method_id,sandbox)
          wrap = self.new
          wrap.klass = klass
          wrap.recv = recv
          wrap.method_name = method_name
          wrap.method_id = method_id
          wrap.sandbox = sandbox

          if block_given?
            yield(wrap)
          end

          return wrap.redirect_with_unhook(:call_with_rehook)
      end
    end

    # Used internally
    class InheritedWrapper < MethodWrapper
      def call(*args)
        subclass = args.first
        privileges.object(subclass).allow :new
        privileges.instances_of(subclass).allow :initialize
        original_call(*args)
      end
    end

    # Used internally
    class DummyWrapper < MethodWrapper
      def call(*args)
        if block_given?
          original_call(*args) do |*x|
            yield(*x)
          end
        else
          original_call(*args)
        end
      end
    end

    class RallhookHandler < RallHook::HookHandler
      attr_accessor :sandbox

      def wrap(recv)
        ObjectWrapper.new(recv)
      end

      def handle_method(klass, recv, method_name, method_id)
        source = nil
        if method_name

          source = caller.first.split(":").first
          dest_source = klass.shadow.instance_method(method_name).body.file

          privileges = nil
          if source != dest_source then
            privileges = sandbox.privileges[source]
            if privileges then
              privileges = privileges.dup
              loop_source = source
              loop_privileges = privileges

              while loop_privileges and loop_source != dest_source
                unless loop_privileges.allow?(klass,recv,method_name,method_id)
                  raise SecurityError.new("Cannot invoke method #{method_name} on object of class #{klass}")
                end

                loop_privileges = nil
                loop_source = sandbox.chain[loop_source]

                if dest_source then
                  loop_privileges = sandbox.privileges[loop_source]
                else
                  loop_privileges = nil
                end

              end
            end
          end

          if method_name == :inherited and wrap(recv).instance_of? Class
           mw = InheritedWrapper.redirect_handler(klass,recv,method_name,method_id,sandbox)
           mw.recv.privileges = privileges
    	     return mw
          end

          if dest_source == ""
            return DummyWrapper.redirect_handler(klass,recv,method_name,method_id,sandbox)
          end

        end

        if privileges
          privileges.handle_redirection(klass,recv,method_id,sandbox) do |mh|
              mh.privileges = privileges
              mh.source = source
            end
        end
      end # if
    end # Class

    #
    #Run the code in sandbox with the given privileges
    #
    #Example:
    #
    # sandbox = Sandbox.new
    # sandbox.privileges.allow_method :print
    # sandbox.run('print "hello world\n"')
    #
    def run(privileges_ , code = "")
      handler = RallhookHandler.new
      handler.sandbox = self
      alternative_binding = self.eval_binding
      source = generate_id

      self.privileges[source] = privileges_

      if block_given?
        handler.hook do
            yield
        end
      else
        handler.hook do
          eval(code, alternative_binding, source)
        end
      end
    end
  end
end

Shikashi.global_binding = binding()


