require "rubygems"
require "bundler/setup"

require 'ostruct'

class RFlow
  # Your code goes here...
  class << self
    attr_accessor :config
  end

  self.config = OpenStruct.new

  def self.configure
    yield config
  end

end # class RFlow
