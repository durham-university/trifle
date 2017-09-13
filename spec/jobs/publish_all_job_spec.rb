require 'rails_helper'

RSpec.describe Trifle::PublishAllJob do
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest1) { FactoryGirl.create(:iiifmanifest, dirty_state: 'clean') }
  let(:manifest2) { FactoryGirl.create(:iiifmanifest, dirty_state: 'dirty') }
  let(:collection1) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest1]) }
  let(:collection2) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest2]) }
  let( :job ) { Trifle::PublishAllJob.new( ) }
  before { 
    allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') 
    allow(Trifle::IIIFCollection).to receive(:ark_naan).and_return('12345') 
  }
  
  describe "#run_job" do
    let(:mock_actor) { double('recursive_actor') }
    it "publishes all manifests and collections" do
      expect(Trifle::IIIFCollection).to receive(:root_collections).and_return(double('relation', from_solr!: [collection1, collection2]))
      expect(Trifle::RecursivePublishIIIFActor).to receive(:new).and_return(mock_actor)
      expect(mock_actor).to receive(:publish_single_resource).with(kind_of(Trifle::IIIFCollection),false)
      expect(mock_actor).to receive(:publish_recursive) do |resource|
        unless [collection1, collection2].include?(resource)
          raise 'Unexpected resource'
        end
      end .exactly(2).times 
      job.run_job
    end
  end
  
end
