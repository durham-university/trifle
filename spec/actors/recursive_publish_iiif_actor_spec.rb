require 'rails_helper'

RSpec.describe Trifle::RecursivePublishIIIFActor do
  let(:trifle_config) { { 'ark_naan' => '12345', 'published_iiif_url' => 'http://www.example.com/iiif/'} }
  before {
    config = Trifle.config.merge(trifle_config)
    allow(Trifle).to receive(:config).and_return(config)
  }

  let(:manifest) { nil }
  let(:user) {nil}
  let(:options) { { } }
  let(:actor) { Trifle::RecursivePublishIIIFActor.new(manifest,user,options) }
  
  describe "#publish_recursive" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, identifier: ['ark:/12345/t0bc12df34x']) }
    context "with a manifest" do
      it "publishes the manifest" do
        expect(actor).to receive(:publish_single_resource).with(manifest, true)
        actor.publish_recursive(manifest)
      end
    end
    context "with a collection" do
      let(:sub_collection) { FactoryGirl.create(:iiifcollection, identifier: ['ark:/12345/t2de12gh67x']) }
      let(:collection) { FactoryGirl.create(:iiifcollection, identifier: ['ark:/12345/t1bc12gh45x']).tap do |collection|
          collection.ordered_members = [manifest, sub_collection]
          collection.save
        end
      }
      it "publishes the collection and its members" do
        expect(actor).to receive(:publish_recursive).with(collection).and_call_original.ordered
        expect(actor).to receive(:publish_single_resource).with(collection, true).ordered
        expect(actor).to receive(:publish_recursive).with(manifest).and_call_original.ordered
        expect(actor).to receive(:publish_single_resource).with(manifest, true).ordered
        expect(actor).to receive(:publish_recursive).with(sub_collection).and_call_original.ordered
        expect(actor).to receive(:publish_single_resource).with(sub_collection, true).ordered
        
        actor.publish_recursive(collection)
      end
    end
  end
  
  describe "#publish_single_resource" do
    let(:resource) { double('resource') }
    it "sends the resource to publish actor" do
      expect_any_instance_of(Trifle::PublishIIIFActor).to receive(:upload_package) do |single_actor|
        expect(single_actor.log).to eq(actor.log)
        expect(single_actor.model_object).to eql(resource)
      end
      actor.publish_single_resource(resource)
    end
  end
end