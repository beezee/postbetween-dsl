require 'sinatra'
require 'postbetween'

class Postbetween::Server < Sinatra::Base

  get '/handle/:handler' do |h|
    handler = Postbetween.registry[h]
    Postbetween.logger.debug("Requested handler #{h}, got #{handler}")
    puts request
    if handler
      handler.output
    else
      status 404
      "not found"
    end
  end
end

Postbetween::Server.run!