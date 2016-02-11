require 'rails_helper'

RSpec.describe Trifle::IIIFManifest do
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  describe "#add_deposited_image" do
    let(:image) { FactoryGirl.build(:iiifimage, title: 'dummy image') }
    it "adds the image to ordered_members" do
      manifest.add_deposited_image(image)
      expect(manifest.reload.ordered_members.to_a.map(&:title)).to eql(['dummy image'])
    end
  end
  
  describe "#default_container_location!" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest, image_container_location: nil) }
    it "doesn't do anything if already set" do
      manifest.image_container_location = 'dummy'
      manifest.default_container_location!
      expect(manifest.image_container_location).to eql('dummy')
    end
    
    context "with a persisted manifest" do
      before { manifest.save }
      it "sets the container_location to be the same as id" do
        manifest.default_container_location!
        expect(manifest.image_container_location).to eql(manifest.id)
      end
    end
    context "with a new manifest" do
      before {
        allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345')
      }
      it "it reserves an id and sets that as container_location" do
        manifest.default_container_location!
        manifest.save
        expect(manifest.image_container_location).to eql(manifest.id)
      end
    end
  end
end
