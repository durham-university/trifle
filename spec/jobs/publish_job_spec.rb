require 'rails_helper'

RSpec.describe Trifle::PublishJob do
  let(:user) {nil}
  let(:options) { { } }
  let(:destroyed_manifest) { FactoryGirl.create(:iiifmanifest).tap do |man| man.destroy end }
  let(:collection) { FactoryGirl.create(:iiifcollection) }
  let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_parent) }
  let!(:actor) { Trifle::PublishIIIFActor.new(manifest,user,options) }
  let( :job ) { Trifle::PublishJob.new( {resource: manifest } ) }
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }

  describe "#run_job" do
    it "runs PublishIIIFActor" do
      expect(Trifle::PublishIIIFActor).to receive(:new) do |resource|
        expect(resource.id).to eql(manifest.id)
        actor
      end
      expect(actor).to receive(:upload_package).and_return(true)
      expect(actor).not_to receive(:remove_remote_package)
      job.run_job
      expect(actor.instance_variable_get(:@log)).to eql(job.log)
    end
    
    context "when recursive is true" do
      let( :job ) { Trifle::PublishJob.new( {resource: manifest, recursive: true } ) }
      let!(:recursive_actor) { Trifle::RecursivePublishIIIFActor.new(manifest,user,options) }
      it "runs RecursivePublishIIIFActor if recursive" do
        expect(job.recursive).to eql(true)
        expect(Trifle::RecursivePublishIIIFActor).to receive(:new) do |resource|
          expect(resource.id).to eql(manifest.id)
          recursive_actor
        end
        expect(recursive_actor).to receive(:publish_recursive).and_return(true)
        job.run_job
        expect(recursive_actor.instance_variable_get(:@log)).to eql(job.log)
      end
    end
    
    describe "removing iiif" do
      let(:job) { Trifle::PublishJob.new( {resource: collection, remove: destroyed_manifest} ) }
      it "removes iiif" do
        expect(Trifle::PublishIIIFActor).to receive(:new) do |resource|
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
  
  describe "#queue_job" do
    let(:m_job) { Trifle::PublishJob.new( {resource: manifest } ) }
    let(:m_job2) { Trifle::PublishJob.new( {resource: manifest } ) }
    
    let(:c_job) { Trifle::PublishJob.new( {resource: collection, remove: destroyed_manifest} ) }
    let(:c_job2) { Trifle::PublishJob.new( {resource: collection, remove: destroyed_manifest} ) }
    let(:c_job3) { Trifle::PublishJob.new( {resource: collection} ) }
    
    before {
      allow(Trifle.queue).to receive(:push)
      allow(DurhamRails::LockManager.instance).to receive(:lock) do |&block|
        block.call
      end
    }
    
    it "doesn't queue jobs if one is already queued" do
      expect(manifest.background_jobs.count).to eql(0)
      m_job.queue_job
      expect(manifest.background_jobs.count).to eql(1)
      m_job2.queue_job
      expect(manifest.background_jobs.count).to eql(1)
      m_job.job_finished
      m_job2.queue_job
      expect(manifest.background_jobs.count).to eql(2)
      
      expect(collection.background_jobs.count).to eql(0)
      c_job.queue_job
      expect(collection.background_jobs.count).to eql(1)
      c_job2.queue_job
      expect(collection.background_jobs.count).to eql(1)
      c_job.job_finished
      c_job2.queue_job
      expect(collection.background_jobs.count).to eql(2)
      c_job3.queue_job
      expect(collection.background_jobs.count).to eql(3)
    end
  end

end