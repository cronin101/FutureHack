class FrontEnd < Sinatra::Application
  get '/' do
    @title = 'FutureHack demo'
    haml :root
  end
end
