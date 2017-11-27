require 'rails_helper'

RSpec.describe Trifle::RepairManifestJob do
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest) { 
    FactoryGirl.create(:iiifmanifest).tap do |m|
      m.ordered_members << FactoryGirl.create(:iiifimage, image_source: 'oubliette:oubliette1')
      m.ordered_members << FactoryGirl.create(:iiifimage, image_source: 'oubliette:oubliette2')
      m.save
    end
  }
  let( :job ) { Trifle::RepairManifestJob.new( {resource: manifest } ) }
  before {
    allow(Oubliette::API::PreservedFile).to receive(:find).with('oubliette1').and_return(
      double('api_file1a', parent: double('api_batch', files: [
        double('api_file1b', id: 'oubliette1', title: 'title1'),
        double('api_file2', id: 'oubliette2', title: 'title2'),
        double('api_file3', id: 'oubliette3', title: 'title3'),
        double('api_file4', id: 'oubliette4', title: 'title4')
      ]))
    )
  }
  
  describe "#run_job" do
    let(:deposit_actor) { double('deposit_actor') }
    let(:publish_actor) { double('publish_actor') }
    it "deposits missing manifests" do
      expect(Trifle::ImageDepositActor).to receive(:new).and_return(deposit_actor)
      expect(deposit_actor).to receive(:deposit_image_batch) do |batch_data|
        expect(batch_data.length).to eql(2)
        expect(batch_data[0]).to eql({'source_path' => "oubliette:oubliette3", 'title' => 'title3'})
        expect(batch_data[1]).to eql({'source_path' => "oubliette:oubliette4", 'title' => 'title4'})
      end
      expect(Trifle::PublishIIIFActor).to receive(:new).and_return(publish_actor)
      expect(publish_actor).to receive(:upload_package)
      job.run_job
    end
  end
  
end
