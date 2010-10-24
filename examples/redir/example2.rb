 require "rubygems"
 require "shikashi"

 class TestWrapper < Shikashi::Sandbox::MethodWrapper
   def call(*args)
     print "called #{klass}#each block_given?:#{block_given?}, source: #{source}\n"
     if block_given?
      original_call(*args) do |*x|
	print "yielded value #{x.first}\n"
        yield(*x)
      end
     else
      original_call(*args)
     end
   end
 end

 s = Shikashi::Sandbox.new
 perm = Shikashi::Privileges.new
 
 perm.instances_of(Array).allow :each
 perm.instances_of(Array).redirect :each, TestWrapper
 
 perm.instances_of(Enumerable::Enumerator).allow :each
 perm.instances_of(Enumerable::Enumerator).redirect :each, TestWrapper
 
 perm.allow_method :print

 s.run perm, '
  array = [1,2,3]

  array.each do |x|
    print x,"\n"
  end

  enum = array.each
  enum.each do |x|
    print x,"\n"
  end
 '
