require 'sinatra/base'
require 'sinatra/config_file'
require_relative 'app/init'

class Director < Sinatra::Base
  register Sinatra::ConfigFile

  set :root, File.dirname(__FILE__)

  config_file 'config/settings.yml'
end