require 'active_support'
require 'httparty'

module Trifle
  module API
    extend ActiveSupport::Autoload

    autoload :IIIFManifest
    autoload :FetchError
    
    autoload_under 'concerns' do
      autoload :ModelBase
      autoload :APIAuthentication
    end    

    def self.config
      @config ||= begin
        config = {} 
        if defined?(Rails)        
          path = Rails.root.join('config','trifle_api.yml')
          if File.exists?(path)
            config = YAML.load(ERB.new(File.read(path)).result)[Rails.env]
          end
        end
        config
      end
    end
  end
end
