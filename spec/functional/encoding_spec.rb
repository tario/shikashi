# encoding: utf-8
require "test/unit"
require "shikashi"

include Shikashi

describe Sandbox, "Shikashi sandbox" do
  it "Should accept UTF-8 encoding via ruby header comments" do
    Sandbox.new.run("# encoding: utf-8\n'кириллица'").should be == 'кириллица'
  end

  it "Should accept UTF-8 encoding via sandbox run options" do
    Sandbox.new.run("'кириллица'", :encoding => "utf-8").should be == 'кириллица'
  end

  it "Should accept UTF-8 encoding via ruby header comments" do
    Sandbox.new.run("# encoding:        utf-8\n'кириллица'").should be == 'кириллица'
  end

  it "Should accept UTF-8 encoding via ruby header comments" do
    Sandbox.new.run("#        encoding: utf-8\n'кириллица'").should be == 'кириллица'
  end

end
