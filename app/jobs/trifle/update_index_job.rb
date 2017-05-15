module Trifle
  class UpdateIndexJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
    include Trifle::TrifleJob
    
    attr_accessor :recursive
    
    def initialize(params={})
      super(params)
      self.recursive = params.fetch(:recursive, false)
    end
    
    def dump_attributes
      super + [:recursive]
    end        
    
    def run_job
      done = {} # theoretically there could be loops, make sure we don't get in one
      stack = [resource]
      log!(:info, "Updating index (recursive: #{recursive})")
      while stack.any?
        res = stack.pop
        done[res.id] = true
        log!(:info, "Updating index of #{res.id}")
        res.update_index
        if recursive
          res.ordered_members.to_a.each do |m|
            next unless m.is_a?(Trifle::IIIFCollection) || m.is_a?(Trifle::IIIFManifest)
            next if done.key?(m.id)
            done[m.id] = true
            stack.push(m) 
          end
        end
      end
    end
    
  end
end