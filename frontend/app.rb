require 'coffee_script'
require 'sinatra'
require 'haml'

class FrontEnd < Sinatra::Application
end

require_relative 'models/init'
require_relative 'routes/init'
