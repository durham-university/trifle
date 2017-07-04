require 'rails_helper'

RSpec.describe Trifle::MillenniumLinkJob do
  let(:options) { { resource: manifest } }
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  let( :job ) { Trifle::MillenniumLinkJob.new(options) }
  
  describe "#run_job" do
    it "invokes the actor" do
      expect_any_instance_of(Trifle::MillenniumActor).to receive(:upload_package) do |actor|
        expect(actor.model_object).to eq(manifest)
      end
      job.run_job
    end
  end
  
end
