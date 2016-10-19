module Trifle
  module ArkNaanOptionsBehaviour
    extend ActiveSupport::Concern
    include DurhamRails::ArkBehaviour
    
    def initialize(attributes_or_id = nil, &block)
      if(attributes_or_id.is_a?(Hash))
        naan = attributes_or_id[:ark_naan]
        set_ark_naan(naan) if naan
        super(attributes_or_id.except(:ark_naan), &block)
      else
        super(attributes_or_id, &block)
      end
    end    
    
    def set_ark_naan(naan)
      allowed = allowed_ark_naan
      raise "Invalid naan #{naan}" unless naan.nil? || allowed.try(:include?,naan) || allowed.try(:include?,'*')
      @ark_naan = naan
    end
    
    def ark_naan
      @ark_naan || super
    end
    
    def allowed_ark_naan
      ret = self.class.allowed_ark_naan || []
      ret += [ark_naan] unless ret.include?(ark_naan)
      ret
    end
    
    def local_ark
      allowed = allowed_ark_naan
      return nil unless allowed.try(:any?)
      all_arks = self.send(ark_identifier_property).select do |ident| ident.start_with?('ark:/') end
      return all_arks.sort.first if allowed.include?('*')
      all_arks.select do |ident| 
        ident_naan = ident.split('/')[1]
        allowed.include?(ident_naan)
      end .sort.first
    end    
    
    def local_ark_naan
      ark = local_ark
      return nil unless ark
      ark.split('/')[1]
    end
    
    module ClassMethods
      def allowed_ark_naan
        split = self.to_s.split('::')
        raise 'Unable to resolve namespace' unless split.length>1
        namespace = split.first.constantize
        namespace.config['allowed_ark_naan']        
      end      
    end
  end
end