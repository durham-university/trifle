require 'rails_helper'

RSpec.describe Trifle::PublishAllJob do
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest1) { FactoryGirl.create(:iiifmanifest, dirty_state: 'clean') }
  let(:manifest2) { FactoryGirl.create(:iiifmanifest, dirty_state: 'dirty') }
  let(:collection1) { FactoryGirl.create(:iiifcollection) }
  let(:collection2) { FactoryGirl.create(:iiifcollection) }
  let( :job ) { Trifle::PublishAllJob.new( ) }
  before { 
    allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') 
    allow(Trifle::IIIFCollection).to receive(:ark_naan).and_return('12345') 
  }
  
  describe "#run_job" do
    it "publishes all manifests and collections" do
      expect(Trifle::IIIFManifest).to receive(:all).and_return([manifest1, manifest2])
      expect(Trifle::IIIFCollection).to receive(:all).and_return([collection1, collection2])
      expect(Trifle::IIIFCollection).to receive(:root_collections).and_return([collection1, collection2])
      expect(Trifle::PublishIIIFActor).to receive(:new) do |resource,user,opts|
        if [manifest1, manifest2, collection1, collection2].include?(resource)
          double('actor').tap do |actor|
            expect(actor).to receive(:upload_package)
          end
        else
          raise 'Unexpected resource'
        end
      end .exactly(5).times
      job.run_job
    end
  end
  
end
