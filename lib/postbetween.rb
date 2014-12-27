require "postbetween/version"
require "postbetween/postbetween_handler"
require 'logger'

module Postbetween

  @registry = {}
  @logger = Logger.new(STDOUT)
  @logger.level = ENV['PB_LOG_LEVEL'].to_i || Logger::WARN

  def self.logger
    @logger
  end

  def self.registry
    @registry
  end

  def self.register(name, &block)
    header = Postbetween::PostbetweenHandler::Header.new({"Content-Type" => "application/json"})
    body = Postbetween::PostbetweenHandler::Body.new({actions: [{source: "foo"}, {source: "bar"}]})
    query = Postbetween::PostbetweenHandler::Query.new({})
    handler = Postbetween::PostbetweenHandler.new(name, header, body, query)
    @logger.debug("Registering handler #{handler.name}: #{handler}")
    if block_given?
      handler.instance_eval(&block)
    end
    @registry[name] = handler
  end
end
