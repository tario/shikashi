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
require "rubygems"
require "evalhook"
require "shikashi/privileges"
require "shikashi/pick_argument"
require "getsource"
require "timeout"

module Shikashi

  class << self
    attr_accessor :global_binding
  end

  module Timeout


    #raised when reach the timeout in a script execution restricted by timeout (see Sandbox#run)
    class Error < Exception

    end
  end

#The sandbox class run the sandbox, because of internal behaviour only can be use one instance
#of sandbox by thread (each different thread may have its own sandbox running in the same time)
#
#= Example
#
# require "rubygems"
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
      @redirect_hash = Hash.new
    end

# add a chain of sources, used internally
    def add_source_chain(outer, inner)
      @chain[inner] = outer
    end


#Base class to define redirections of methods called in the sandbox
#
#= Example 1
#Basic redirection
#
# require "rubygems"
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
#= Example 2
#Proper block handling on redirection wrapper
#
# require "rubygems"
# require "shikashi"
#
# class TestWrapper < Shikashi::Sandbox::MethodWrapper
#   def call(*args)
#     print "called #{klass}#each block_given?:#{block_given?}, source: #{source}\n"
#     if block_given?
#      original_call(*args) do |*x|
#        print "yielded value #{x.first}\n"
#        yield(*x)
#      end
#     else
#      original_call(*args)
#     end
#   end
# end
#
# s = Shikashi::Sandbox.new
# perm = Shikashi::Privileges.new
#
# perm.instances_of(Array).allow :each
# perm.instances_of(Array).redirect :each, TestWrapper
#
# perm.instances_of(Enumerable::Enumerator).allow :each
# perm.instances_of(Enumerable::Enumerator).redirect :each, TestWrapper
#
# perm.allow_method :print
#
# s.run perm, '
#  array = [1,2,3]
#
#  array.each do |x|
#    print x,"\n"
#  end
#
#  enum = array.each
#  enum.each do |x|
#    print x,"\n"
#  end
# '
    class MethodWrapper

      class MethodRedirect
        include RedirectHelper::MethodRedirect

        attr_accessor :klass
        attr_accessor :method_name
        attr_accessor :recv
      end

      attr_accessor :recv
      attr_accessor :method_name
      attr_accessor :klass
      attr_accessor :sandbox
      attr_accessor :privileges
      attr_accessor :source

      def self.redirect_handler(klass,recv,method_name,method_id,sandbox)
        mw = self.new
        mw.klass = klass
        mw.recv = recv
        mw.method_name = method_name
        mw.sandbox = sandbox

        if block_given?
          yield(mw)
        end

        mr = MethodRedirect.new

        mr.recv = mw
        mr.klass = mw.class
        mr.method_name = :call

        mr
      end

      def original_call(*args)
        if block_given?
          klass.instance_method(method_name).bind(recv).call(*args) do |*x|
            yield(*x)
          end
        else
          klass.instance_method(method_name).bind(recv).call(*args)
        end
      end
    end

    class EvalhookHandler < EvalHook::HookHandler
      attr_accessor :sandbox
      attr_accessor :redirect

      def handle_gasgn( global_id, value )
        source = caller[1].split(":").first

        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.global_allowed? global_id
            raise SecurityError.new("Cannot assign global variable #{global_id}")
          end
        end

        nil
      end

      def handle_cdecl(klass, const_id, value)
        source = caller[1].split(":").first

        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.const_allowed? "#{klass}::#{const_id}"
            raise SecurityError.new("Cannot assign const #{klass}::#{const_id}")
          end
        end

        nil


      end

      def handle_method(klass, recv, method_name)
        source = nil

        method_id = 0

        if method_name

          source = caller[1].split(":").first
          dest_source = klass.instance_method(method_name).body.file

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

          return nil if method_name == :instance_eval
          return nil if method_name == :binding

          if method_name
            wclass = @redirect[method_name.to_sym]
            if wclass then
              return wclass.redirect_handler(klass,recv,method_name,method_id,sandbox)
            end
          end

        end

        if privileges
          privileges.handle_redirection(klass,recv,method_name,sandbox) do |mh|
            mh.privileges = privileges
            mh.source = source
          end
        end

      end # if
    end # Class

    #Run the code in sandbox with the given privileges, also run privileged code in the sandbox context for
    #execution of classes and methods defined in the sandbox from outside the sandbox if a block is passed
    # (see examples)
    #
    #call-seq: run(arguments)
    #
    #Arguments
    #
    # :code       Mandatory argument of class String with the code to execute restricted in the sandbox
    # :privileges Optional argument of class Shikashi::Sandbox::Privileges to indicate the restrictions of the
    #             code executed in the sandbox. The default is an empty Privileges (absolutly no permission)
    #             Must be of class Privileges or passed as hash_key (:privileges => privileges)
    # :binding    Optional argument with the binding object of the context where the code is to be executed
    #             The default is a binding in the global context
    # :source     Optional argument to indicate the "source name", (visible in the backtraces). Only can
    #             be specified as hash parameter
    # :timeout    Optional argument to restrict the execution time of the script to a given value in seconds
    #             (accepts integer and decimal values), when timeout hits Shikashi::Timeout::Error is raised
    #
    #
    #The arguments can be passed in any order and using hash notation or not, examples:
    #
    # sandbox.run code, privileges
    # sandbox.run code, :privileges => privileges
    # sandbox.run :code => code, :privileges => privileges
    # sandbox.run code, privileges, binding
    # sandbox.run binding, code, privileges
    # #etc
    # sandbox.run binding, code, privileges, :source => source
    # sandbox.run binding, :code => code, :privileges => privileges, :source => source
    #
    #Example:
    #
    # require "rubygems"
    # require "shikashi"
    #
    # include Shikashi
    #
    # sandbox = Sandbox.new
    # privileges = Privileges.new
    # privileges.allow_method :print
    # sandbox.run('print "hello world\n"', :privileges => privileges)
    #
    #Example 2:
    # require "rubygems"
    # require "shikashi"
    #
    # include Shikashi
    #
    # sandbox = Sandbox.new
    # privileges = Privileges.new
    # privileges.allow_method :print
    # privileges.allow_method :singleton_method_added
    #
    # sandbox.run('
    #   def self.foo
    #     print "hello world\n"
    #   end
    #    ', :privileges => privileges)
    #
    # #outside of this block, the method foo defined in the sandbox are invisible
    # sandbox.run do
    #   self.foo
    # end
    #
    #

    def run(*args)

      handler = EvalhookHandler.new
      handler.redirect = @redirect_hash
      handler.sandbox = self

      t = args.pick(:timeout) do nil end
      raise Shikashi::Timeout::Error if t == 0
      t = t || 0

      begin
        timeout t do
          privileges_ = args.pick(Privileges,:privileges) do Privileges.new end
          code = args.pick(String,:code)
          binding_ = args.pick(Binding,:binding) do Shikashi.global_binding end
          source = args.pick(:source) do generate_id end

          self.privileges[source] = privileges_

          handler.evalhook(code, binding_, source)
        end
      rescue ::Timeout::Error
        raise Shikashi::Timeout::Error
      end
    end


    #redirects a method with given name to a wrapper of the given class
    #example:
    # class PrintWrapper < Shikashi::Sandbox::MethodWrapper
    #   def call(*args)
    #     print "invoked print\n"
    #     original_call(*args)
    #   end
    # end
    #
    # sandbox.redirect(:print, PrintWrapper)
    # sandbox.redirect(:print, :wrapper_class => PrintWrapper)
    # sandbox.redirect(:method_name => :print, :wrapper_class => PrintWrapper)
    #

    def redirect(*args)
      mname = args.pick(Symbol, :method_name)
      wclass = args.pick(Class, :wrapper_class)
      @redirect_hash[mname] = wclass
    end

  end
end

Shikashi.global_binding = binding()


