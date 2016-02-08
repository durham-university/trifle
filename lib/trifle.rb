require 'sass-rails'
require 'bootstrap-sass'
require 'bootstrap-sass-extras'
require 'jquery-rails'
require 'jquery-ui-rails'
require 'simple_form'
require 'rsolr'
require 'active-fedora'
require 'active_fedora/noid'
require 'hydra-editor'
require 'hydra/works'
require 'hydra/pcdm'
require 'durham_rails'
require "trifle/engine"

module Trifle
  def self.queue
    @queue ||= Trifle::Resque::Queue.new('trifle')
  end

  def self.image_server_url
    self.config['image_server_url']
  end

  def self.config
    @config ||= begin
      path = Rails.root.join('config','trifle.yml')
      if File.exists?(path)
        YAML.load(ERB.new(File.read(path)).result)[Rails.env]
      else
        {}
      end
    end
  end

end
