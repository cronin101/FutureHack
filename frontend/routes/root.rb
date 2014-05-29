class FrontEnd < Sinatra::Application
  get '/' do
    @title = 'FutureHack demo'
    haml :root
  end

  get '/root.js' do
    coffee :root
  end
end
