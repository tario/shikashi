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

    attr_reader :hook_handler

#
#   Same as Sandbox.new.run
#

    def self.run(*args)
      Sandbox.new.run(Shikashi.global_binding, *args)
    end
#
# Generate a random source file name for the sandbox, used internally
#

    def generate_id
      "sandbox-#{rand(1000000)}"
    end

    def initialize
      @privileges = Hash.new
      @chain = Hash.new
      @hook_handler_list = Array.new
      @hook_handler = instantiate_evalhook_handler
      @hook_handler.sandbox = self
      @base_namespace = create_adhoc_base_namespace
      @hook_handler.base_namespace = @base_namespace
    end

# add a chain of sources, used internally
    def add_source_chain(outer, inner)
      @chain[inner] = outer
    end

    def base_namespace
      @base_namespace
    end

    class Packet
      def initialize(evalhook_packet, default_privileges, source) #:nodoc:
        @evalhook_packet = evalhook_packet
        @default_privileges = default_privileges
        @source = source
      end

      #Run the code in the package
      #
      #call-seq: run(arguments)
      #
      #Arguments
      #
      # :binding    Optional argument with the binding object of the context where the code is to be executed
      #             The default is a binding in the global context
      # :timeout    Optional argument to restrict the execution time of the script to a given value in seconds
      def run(*args)
        t = args.pick(:timeout) do nil end
        binding_ = args.pick(Binding,:binding) do
          nil
        end

        begin
          timeout t do
            @evalhook_packet.run(binding_, @source, 0)
          end
        rescue ::Timeout::Error
          raise Shikashi::Timeout::Error
        end
      end

      # Dispose the objects associated with this code package
      def dispose
        @evalhook_packet.dispose
      end
    end

    class EvalhookHandler < EvalHook::HookHandler
      attr_accessor :sandbox

      def handle_xstr( str )
        source = get_caller

        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.xstr_allowed?
            raise SecurityError, "fobidden shell commands"
          end
        end

        `#{str}`
      end

      def handle_gasgn( global_id, value )
        source = get_caller

        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.global_write_allowed? global_id
            raise SecurityError.new("Cannot assign global variable #{global_id}")
          end
        end

        nil
      end

      def handle_gvar(global_id)
        source = get_caller
        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.global_read_allowed? global_id
            raise SecurityError, "cannot access global variable #{global_id}"
          end
        end

        nil
      end

      def handle_const(name)
        source = get_caller
        privileges = sandbox.privileges[source]
        if privileges
          constants = sandbox.base_namespace.constants
          unless constants.include? name or constants.include? name.to_sym
            unless privileges.const_read_allowed? name.to_s
              raise SecurityError, "cannot access constant #{name}"
            end
          end
        end

        const_value(sandbox.base_namespace.const_get(name))
      end

      def handle_cdecl(klass, const_id, value)
        source = get_caller

        privileges = sandbox.privileges[source]
        if privileges
          unless privileges.const_write_allowed? "#{klass}::#{const_id}"
            if (klass == Object)
              unless privileges.const_write_allowed? const_id.to_s
                raise SecurityError.new("Cannot assign const #{const_id}")
              end
            else
              raise SecurityError.new("Cannot assign const #{klass}::#{const_id}")
            end
          end
        end

        nil
      end

      def handle_method(klass, recv, method_name)
        source = nil

        method_id = 0

        if method_name

          source = self.get_caller
          m = begin
            klass.instance_method(method_name)
          rescue
            method_name = :method_missing
            klass.instance_method(:method_missing)
          end
          dest_source = m.body.file

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

    #Run the code in sandbox with the given privileges
    # (see examples)
    #
    # Arguments
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
    # :base_namespace   Alternate module to contain all classes and constants defined by the unprivileged code
    #                   if not specified, by default, the base_namespace is created with the sandbox itself
    # :no_base_namespace  Specify to do not use a base_namespace (default false, not recommended to change)
    # :encoding           Specify the encoding of source (example: "utf-8"), the encoding also can be
    #                     specified on header like a ruby normal source file
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
    #
    def run(*args)
      run_i(*args)
    end

    #Creates a packet of code with the given privileges to execute later as many times as neccessary
    #
    # (see examples)
    #
    # Arguments
    #
    # :code             Mandatory argument of class String with the code to execute restricted in the sandbox
    # :privileges       Optional argument of class Shikashi::Sandbox::Privileges to indicate the restrictions of the
    #                   code executed in the sandbox. The default is an empty Privileges (absolutly no permission)
    #                   Must be of class Privileges or passed as hash_key (:privileges => privileges)
    # :source           Optional argument to indicate the "source name", (visible in the backtraces). Only can
    #                   be specified as hash parameter
    # :base_namespace   Alternate module to contain all classes and constants defined by the unprivileged code
    #                   if not specified, by default, the base_namespace is created with the sandbox itself
    # :no_base_namespace  Specify to do not use a base_namespace (default false, not recommended to change)
    # :encoding           Specify the encoding of source (example: "utf-8"), the encoding also can be
    #                     specified on header like a ruby normal source file
    #
    # NOTE: arguments are the same as for Sandbox#run method, except for timeout and binding which can be
    # used when calling Shikashi::Sandbox::Packet#run
    #
    #Example:
    #
    # require "rubygems"
    # require "shikashi"
    #
    # include Shikashi
    #
    # sandbox = Sandbox.new
    #
    # privileges = Privileges.allow_method(:print)
    #
    # # this is equivallent to sandbox.run('print "hello world\n"')
    # packet = sandbox.packet('print "hello world\n"', privileges)
    # packet.run
    #
    def packet(*args)
      code = args.pick(String,:code)
      base_namespace = args.pick(:base_namespace) do nil end
      no_base_namespace = args.pick(:no_base_namespace) do @no_base_namespace end
      privileges_ = args.pick(Privileges,:privileges) do Privileges.new end
      encoding = get_source_encoding(code) || args.pick(:encoding) do nil end

      hook_handler = nil

      if base_namespace
        hook_handler = instantiate_evalhook_handler
        hook_handler.base_namespace = base_namespace
        hook_handler.sandbox = self
      else
        hook_handler = @hook_handler
        base_namespace = hook_handler.base_namespace
      end
      source = args.pick(:source) do generate_id end

      self.privileges[source] = privileges_

      code = "nil;\n " + code

      unless no_base_namespace
        if (eval(base_namespace.to_s).instance_of? Module)
          code = "module #{base_namespace}\n #{code}\n end\n"
        else
          code = "class #{base_namespace}\n #{code}\n end\n"
        end
      end

      if encoding
        code = "# encoding: #{encoding}\n" + code
      end

      evalhook_packet = @hook_handler.packet(code)
      Shikashi::Sandbox::Packet.new(evalhook_packet, privileges_, source)
    end

    def create_hook_handler(*args)
      hook_handler = instantiate_evalhook_handler
      hook_handler.sandbox = self
      @base_namespace = args.pick(:base_namespace) do create_adhoc_base_namespace end
      hook_handler.base_namespace = @base_namespace

      source = args.pick(:source) do generate_id end
      privileges_ = args.pick(Privileges,:privileges) do Privileges.new end

      self.privileges[source] = privileges_

      hook_handler
    end

    def dispose
      @hook_handler_list.each(&:dispose)
    end
private

    def instantiate_evalhook_handler
      newhookhandler = EvalhookHandler.new
      @hook_handler_list << newhookhandler
      newhookhandler
    end

    def create_adhoc_base_namespace
      rnd_module_name = "SandboxBasenamespace#{rand(100000000)}"

      eval("module Shikashi::Sandbox::#{rnd_module_name}; end")
      @base_namespace = eval("Shikashi::Sandbox::#{rnd_module_name}")
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
            base_namespace = args.pick(:base_namespace) do nil end
            no_base_namespace = args.pick(:no_base_namespace) do @no_base_namespace end
            encoding = get_source_encoding(code) || args.pick(:encoding) do nil end

            hook_handler = nil

            if base_namespace
              hook_handler = instantiate_evalhook_handler
              hook_handler.base_namespace = base_namespace
              hook_handler.sandbox = self
            else
              hook_handler = @hook_handler
              base_namespace = hook_handler.base_namespace
            end

            self.privileges[source] = privileges_
            code = "nil;\n " + code

            unless no_base_namespace
              if (eval(base_namespace.to_s).instance_of? Module)
                code = "module #{base_namespace}\n #{code}\n end\n"
              else
                code = "class #{base_namespace}\n #{code}\n end\n"
              end
            end

            if encoding
              # preend encoding
              code = "# encoding: #{encoding}\n" + code
            end
            hook_handler.evalhook(code, binding_, source)
          end
        rescue ::Timeout::Error
          raise Shikashi::Timeout::Error
        end
      end
    end

    def get_source_encoding(code)
      first_line = code.to_s.lines.first.to_s
      m = first_line.match(/encoding:(.*)$/)
      if m
        m[1]
      else
        nil
      end
    end

  end
end

Shikashi.global_binding = binding()


