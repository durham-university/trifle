module Trifle
  class MillenniumLinkJob
    include DurhamRails::Jobs::JobBase
    include DurhamRails::Jobs::WithResource
    include Trifle::TrifleJob
    
    def run_job
      actor = Trifle::MillenniumActor.new(resource)
      actor.instance_variable_set(:@log,log)
      actor.upload_package
    end
    
  end
end