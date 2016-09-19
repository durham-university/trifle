require 'active_support'
require 'httparty'
require 'durham_rails'

module Trifle
  module API
    extend ActiveSupport::Autoload

    autoload :IIIFManifest
    autoload :IIIFCollection
    autoload :FetchError
    
    autoload_under 'concerns' do
      autoload :ModelBase
      autoload :APIAuthentication
    end    

    def self.config
      @config ||= begin
        config = {} 
        if defined?(Rails) && Rails.root
          path = Rails.root.join('config','trifle_api.yml')
          if File.exists?(path)
            config = YAML.load(ERB.new(File.read(path)).tap do |erb| erb.filename = path.to_s end .result)[Rails.env] || {}
          end
        end
        config
      end
    end
  end
end
