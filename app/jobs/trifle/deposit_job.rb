module Trifle
  class DepositJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
#    include DurhamRails::Jobs::WithUser
    include Trifle::TrifleJob
    
    attr_accessor :deposit_items
    
    def initialize(params={})
      super(params)
      self.deposit_items = Array.wrap(params[:deposit_items])
    end
    
    def dump_attributes
      super + [:deposit_items]
    end    
    
    def validate_job!
      super
      raise "No items to deposit giver" unless deposit_items.any?
    end
    
    
    def run_job
      actor = Trifle::ImageDepositActor.new(resource)
      actor.instance_variable_set(:@log,log)
      actor.deposit_image_batch(deposit_items)
    end
    
  end
end