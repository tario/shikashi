 require "rubygems"
 require "shikashi"

 class TestWrapper < Shikashi::Sandbox::MethodWrapper
   def call(*args)
     print "called foo from source: #{source}, arguments: #{args.inspect} \n"
     original_call(*args)
   end
 end

 class X
   def foo
     print "original foo\n"
   end
 end

 s = Shikashi::Sandbox.new
 perm = Shikashi::Privileges.new

 perm.object(X).allow :new
 perm.instances_of(X).allow :foo

 # redirect calls to foo to TestWrapper
 perm.instances_of(X).redirect :foo, TestWrapper

 s.run(perm,"X.new.foo")
