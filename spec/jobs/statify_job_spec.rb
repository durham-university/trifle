require 'rails_helper'

RSpec.describe Trifle::StatifyJob do
  let(:user) {nil}
  let(:options) { { } }
  let(:destroyed_manifest) { FactoryGirl.create(:iiifmanifest).tap do |man| man.destroy end }
  let(:collection) { FactoryGirl.create(:iiifcollection) }
  let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_parent) }
  let!(:actor) { Trifle::StaticIIIFActor.new(manifest,user,options) }
  let( :job ) { Trifle::StatifyJob.new( {resource: manifest } ) }
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }

  describe "#run_job" do
    it "runs StaticIIIFActor" do
      expect(Trifle::StaticIIIFActor).to receive(:new) do |resource|
        expect(resource.id).to eql(manifest.id)
        actor
      end
      expect(actor).to receive(:upload_package).and_return(true)
      expect(actor).not_to receive(:remove_remote_package)
      job.run_job
      expect(actor.instance_variable_get(:@log)).to eql(job.log)
    end
    
    describe "removing iiif" do
      let(:job) { Trifle::StatifyJob.new( {resource: collection, remove: destroyed_manifest} ) }
      it "removes iiif" do
        expect(Trifle::StaticIIIFActor).to receive(:new) do |resource|
          expect(resource.id).to eql(collection.id)
          actor
        end
        expect(actor).to receive(:upload_package).and_return(true)
        expect(actor).to receive(:remove_remote_package).with(destroyed_manifest.local_ark, 'manifest').and_return(true)
        job.run_job
        expect(actor.instance_variable_get(:@log)).to eql(job.log)
      end
    end
  end

end