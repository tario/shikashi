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

module Shikashi

  class << self
    attr_accessor :global_binding
  end

  class Sandbox

    attr_accessor :privileges
    attr_accessor :current_privileges
    attr_reader :source

    def initialize
      @privileges = Shikashi::Privileges.new

      @privileges.allow_method :eval
      @privileges.allow_exceptions
    end

    def self.generate_id
      "sandbox-#{rand(1000000)}"
    end


    class SandboxWrapper < RallHook::Helper::MethodWrapper
      attr_accessor :sandbox
      def self.redirect_handler(klass,recv,method_name,method_id,sandbox)
          wrap = self.new
          wrap.klass = klass
          wrap.recv = recv
          wrap.method_name = method_name
          wrap.method_id = method_id
          wrap.sandbox = sandbox
          return wrap.redirect_with_unhook(:call_with_rehook)
      end
    end

    class InheritedWrapper < SandboxWrapper
      def call(subclass)
        sandbox.privileges.object(subclass).allow :new
        sandbox.privileges.instances_of(subclass).allow :initialize
        original_call(subclass)
      end
    end

    class RallhookHandler < RallHook::HookHandler
      attr_accessor :sandbox
      def handle_method(klass, recv, method_name, method_id)
        if (method_name)
          if recv.method(klass,method_id).body.file == sandbox.source
            # allowed because the method are defined inside the sandbox
            if sandbox.current_privileges != sandbox.privileges
              # wrap method call
            end

            # continue with the method call
            return nil
          end
        end

        if method_name == :inherited and recv.instance_of? Class
          return InheritedWrapper.redirect_handler(klass,recv,method_name,method_id,sandbox)
        end

        unless sandbox.privileges.allow?(klass,recv,method_name,method_id)
          raise SecurityError.new("Cannot invoke method #{method_name} over #{recv}")
        end
        nil
      end
    end

    #
    # Run the code in sandbox with the given privileges
    #
    def run(code , alternative_binding = nil)
      @source = Sandbox.generate_id
      handler = RallhookHandler.new
      handler.sandbox = self
      alternative_binding = alternative_binding || Shikashi.global_binding
      handler.hook do
        eval(code, alternative_binding, @source)
      end
    end
  end
end

Shikashi.global_binding = binding()


