require "shikashi"

include Shikashi

describe Privileges, "Shikashi::Privileges" do

  it "allow_method should return object of Privileges class" do
    Privileges.allow_method(:foo).should be_kind_of(Privileges)
  end

  it "allow_global_read should return object of Privileges class" do
    Privileges.allow_global_read(:$a).should be_kind_of(Privileges)
  end

  it "allow_global_write should return object of Privileges class" do
    Privileges.allow_global_write(:$a).should be_kind_of(Privileges)
  end

  it "allow_const_read should return object of Privileges class" do
    Privileges.allow_const_read(:$a).should be_kind_of(Privileges)
  end

  it "allow_const_write should return object of Privileges class" do
    Privileges.allow_const_write(:$a).should be_kind_of(Privileges)
  end

end