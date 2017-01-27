require 'sass-rails'
require 'bootstrap-sass'
require 'bootstrap-sass-extras'
require 'jquery-rails'
require 'jquery-ui-rails'
require 'simple_form'
require 'iiif/presentation'
require 'rsolr'
require 'active-fedora'
require 'active_fedora/noid'
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
  
  def self.iiif_host
    self.config.fetch('iiif_host','http://localhost:3000')
  end
  
  def self.iiif_service
    self.config.fetch('image_service_url','http://localhost/iipsrv/iipsrv.fcgi?IIIF=')
  end
  
  def self.mirador_location
    self.config.fetch('mirador_location','')
  end

  def self.config
    @config ||= begin
      path = Rails.root.join('config','trifle.yml')
      if File.exists?(path)
        YAML.load(ERB.new(File.read(path)).tap do |erb| erb.filename = path.to_s end .result)[Rails.env]
      else
        {}
      end
    end
  end

  def self.cached_url_helpers
    @cached_url_helpers ||= DurhamRails::CachedURLHelpers.new(Trifle::Engine.routes.url_helpers, self.iiif_host)
  end
end
