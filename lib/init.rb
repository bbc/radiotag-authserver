require "rubygems"
require "bundler"
Bundler.require

# add require_relative
unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative 'authserver'
require_relative 'config_helper'
require_relative 'token'

config = ConfigHelper.load_config("config/database.yml")

def mysql_connect_string(config, environment)
  db_config = config[environment]
  port_string = db_config[:port]
  if port_string
    port_string = ":#{port_string}"
  end
  # user:password@host[:port]/database
  "#{db_config[:user]}:#{db_config[:password]}@#{db_config[:host]}#{port_string}/#{db_config[:database]}"
end

configure :test do
  puts 'Test configuration in use'
  DataMapper.setup(:default, "sqlite::memory:")
  DataMapper.auto_migrate!
end

configure :development do
  puts 'Development configuration in use'
  DataMapper.setup(:default, "mysql://#{mysql_connect_string(config, :development)}?encoding=UTF-8")
  DataMapper.auto_upgrade!

  Token.first_or_create(:token => 'b86bfdfb-5ff5-4cc7-8c61-daaa4804f188', :value => { :scope => :unpaired })
  Token.first_or_create(:token => 'ddc7f510-9353-45ad-9202-746ffe3b663a', :value => { :scope => :can_register })
end

configure :production do
  puts 'Production configuration in use'
  DataMapper.setup(:default, "mysql://#{mysql_connect_string(config, :production)}?encoding=UTF-8")
  DataMapper.auto_upgrade!

  Token.first_or_create(:token => 'b86bfdfb-5ff5-4cc7-8c61-daaa4804f188', :value => { :scope => :unpaired })
  Token.first_or_create(:token => 'ddc7f510-9353-45ad-9202-746ffe3b663a', :value => { :scope => :can_register })
end

