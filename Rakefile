require 'rubygems'

require 'sinatra'
require "sinatra/config_file"
config_file 'config/settings.yml'

Dir.glob('tasks/*.rake').each { |r| import r }