require 'rails_helper'

RSpec.describe Trifle::PublishDirtyJob do
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest1) { FactoryGirl.create(:iiifmanifest, dirty_state: 'dirty') }
  let(:manifest2) { FactoryGirl.create(:iiifmanifest, dirty_state: 'dirty') }
  let( :job ) { Trifle::PublishDirtyJob.new( ) }
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
  
  describe "#run_job" do
    it "publishes all dirty manifests" do
      expect(Trifle::IIIFManifest).to receive(:all_dirty).and_return([manifest1, manifest2])
      expect(Trifle::PublishIIIFActor).to receive(:new) do |manifest|
        if manifest==manifest1 || manifest==manifest2
          double('actor').tap do |actor|
            expect(actor).to receive(:upload_package)
          end
        else
          raise 'Unexpected manifest'
        end
      end .twice
      job.run_job
    end
  end
  
end
