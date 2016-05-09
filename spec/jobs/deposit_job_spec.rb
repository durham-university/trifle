require 'rails_helper'

RSpec.describe Trifle::DepositJob do
  let(:manifest) { FactoryGirl.create(:iiifmanifest, image_container_location: 'folder') }
  let(:user) {nil}
  let(:options) { { } }
  let!(:deposit_actor) { Trifle::ImageDepositActor.new(manifest,user,options) }
  let!(:iiif_actor) { Trifle::StaticIIIFActor.new(manifest,user,options) }
  let(:deposit_items) { double('deposit_items') }
  let( :job ) { Trifle::DepositJob.new( {resource: manifest, deposit_items: deposit_items } ) }

  describe "#run_job" do
    it "runs ImageDepositActor and StaticIIIFActor" do
      expect(Trifle::ImageDepositActor).to receive(:new).and_return(deposit_actor)
      expect(Trifle::StaticIIIFActor).to receive(:new).and_return(iiif_actor)
      expect(deposit_actor).to receive(:deposit_image_batch).and_return(true)
      expect(iiif_actor).to receive(:upload_package).and_return(true)
      job.run_job
      expect(deposit_actor.instance_variable_get(:@log)).to eql(job.log)
      expect(iiif_actor.instance_variable_get(:@log)).to eql(job.log)
    end
  end

end