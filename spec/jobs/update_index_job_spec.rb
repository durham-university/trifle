require 'rails_helper'

RSpec.describe Trifle::UpdateIndexJob do
  let(:user) {nil}
  let(:options) { { resource: collection1, recursive: true } }
  let(:collection1) { FactoryGirl.create(:iiifcollection) }
  let(:collection2) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest1, manifest2]) }
  let(:manifest1) { FactoryGirl.create(:iiifmanifest) }
  let(:manifest2) { FactoryGirl.create(:iiifmanifest) }
  let( :job ) { Trifle::UpdateIndexJob.new(options) }
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
  
  describe "#run_job" do
    it "updates recursively" do
      collection1.ordered_members << collection2
      collection1.save
      expect(Trifle::IIIFManifest.all_in_collection(collection1).to_a).to eql([])
      job.run_job
      expect(Trifle::IIIFManifest.all_in_collection(collection1).to_a.map(&:id)).to match_array([manifest1.id, manifest2.id])
    end
  end
  
end
