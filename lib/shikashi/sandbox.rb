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
require "evalmimic"

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

    attr_reader :hook_handler

#
# Generate a random source file name for the sandbox, used internally
#

    def generate_id
      "sandbox-#{rand(1000000)}"
    end

    def initialize
      @privileges = Hash.new
      @chain = Hash.new
    end

# add a chain of sources, used internally
    def add_source_chain(outer, inner)
      @chain[inner] = outer
    end

    def base_namespace
      @base_namespace
    end

    class EvalhookHandler < EvalHook::HookHandler
      attr_accessor :sandbox

      def handle_xstr( str )
        raise SecurityError, "fobidden shell commands"
      end

      def handle_gasgn( global_id, value )
        source = get_caller

        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.global_allowed? global_id
            raise SecurityError.new("Cannot assign global variable #{global_id}")
          end
        end

        nil
      end

      def handle_cdecl(klass, const_id, value)
        source = get_caller

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

          source = self.get_caller
          dest_source = klass.instance_method(method_name).body.file

          privileges = nil
          if source != dest_source then
            privileges = sandbox.privileges[source]

            unless privileges then
               raise SecurityError.new("Cannot invoke method #{method_name} on object of class #{klass}")
            else
#              privileges = privileges.dup
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

          nil

        end


      end # if

      def get_caller
        caller[2].split(":").first
      end
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
    end

    define_eval_method :run
    def internal_eval(b_, args)

      newargs = Array.new

      timeout = args.pick(:timeout) do nil end
      privileges_ = args.pick(Privileges,:privileges) do Privileges.new end
      code = args.pick(String,:code)
      binding_ = args.pick(Binding,:binding) do b_ end
      source = args.pick(:source) do nil end
      base_namespace = args.pick(:base_namespace) do create_adhoc_base_namespace end
      @base_namespace = base_namespace
      no_base_namespace = args.pick(:no_base_namespace) do false end

      run_i(code, privileges_, binding_, :base_namespace => base_namespace, :timeout => timeout, :no_base_namespace => no_base_namespace)
    end

    def create_hook_handler(*args)
      hook_handler = EvalhookHandler.new
      hook_handler.sandbox = self
      @base_namespace = args.pick(:base_namespace) do create_adhoc_base_namespace end
      hook_handler.base_namespace = @base_namespace

      source = args.pick(:source) do generate_id end
      privileges_ = args.pick(Privileges,:privileges) do Privileges.new end

      self.privileges[source] = privileges_

      hook_handler
    end

    module Z

    end
private

    def create_adhoc_base_namespace
      @base_namespace = Sandbox::Z
      @base_namespace
    end

    def run_i(*args)


      t = args.pick(:timeout) do nil end
      raise Shikashi::Timeout::Error if t == 0
      t = t || 0

      if block_given?
        yield
      else
        begin
          timeout t do
            privileges_ = args.pick(Privileges,:privileges) do Privileges.new end
            code = args.pick(String,:code)
            binding_ = args.pick(Binding,:binding) do Shikashi.global_binding end
            source = args.pick(:source) do generate_id end
            base_namespace = args.pick(:base_namespace) do create_adhoc_base_namespace end
            no_base_namespace = args.pick(:no_base_namespace) do false end

            @hook_handler = self.create_hook_handler(
                    :base_namespace => base_namespace,
                    :privileges => privileges_,
                    :source => source
                    )

            code = "nil;\n " + code

            unless no_base_namespace
              if (base_namespace.instance_of? Module)
                code = "module #{base_namespace}\n #{code}\n end\n"
              else
                code = "class #{base_namespace}\n #{code}\n end\n"
              end
            end

            @hook_handler.evalhook(code, binding_, source)
          end
        rescue ::Timeout::Error
          raise Shikashi::Timeout::Error
        end
      end
    end

  end


end

Shikashi.global_binding = binding()


