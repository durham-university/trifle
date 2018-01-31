require 'rails_helper'
require 'marc'

RSpec.describe Trifle::LayersActor do
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
  before { allow(Trifle::IIIFImage).to receive(:ark_naan).and_return('12345') }
  let(:user) {nil}
  let(:options) { { } }
  let(:manifest) { FactoryGirl.build(:iiifmanifest, :with_images, num_images: 4) }
  let(:image) { manifest.images[0] }
  let(:target_images) { [manifest.images[2], manifest.images[3]] }
  let(:actor) { Trifle::LayersActor.new(image,user,options) }

  describe "#make_image_a_layer" do
    let(:opts) {{test: 'test'}}
    it "delegates to make_images_layers" do
      expect(actor).to receive(:make_images_layers).with([target_images[0]], opts)
      actor.make_image_a_layer(target_images[0], opts)
    end
  end

  describe "make_images_layers" do
    it "makes sure targets are images" do
      expect {
        actor.make_images_layers([target_images[0], manifest])
      } .to raise_error("Parameter is not a Trifle::IIIFImage")
    end

    it "makes sure target != model_object" do
      expect {
        actor.make_images_layers([target_images[0], image])
      } .to raise_error("Tried to convert containing object into a layer in itself")
    end

    it "converts to layer" do
      target_images[0].image_source = 'oubliette:testtest1'
      expect(image.layers).to be_empty
      expect(actor.make_images_layers(target_images)).to eql(true)
      image.reload
      expect(image.layers.count).to eql(2)
      expect(image.layers[0].title).to eql(target_images[0].title)
      expect(image.layers[0].description).to eql(target_images[0].description)
      expect(image.layers[0].width).to eql(target_images[0].width.to_i)
      expect(image.layers[0].height).to eql(target_images[0].height.to_i)
      expect(image.layers[0].image_location).to eql(target_images[0].image_location)
      expect(image.layers[0].image_source).to eql(target_images[0].image_source)
      expect(image.layers[0].embed_xywh).to be_present
      expect {
        target_images[0].reload
      } .to raise_error(ActiveFedora::ObjectNotFoundError)
    end
  end

  describe "make_layer_an_image" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_images, num_images: 4) }
    let(:image) {
      FactoryGirl.create(:iiifimage, :with_layers).tap do |image|
        manifest.ordered_members << image
        manifest.save
      end
    }
    let!(:layer) { image.layers[0] }
    let(:actor) { Trifle::LayersActor.new(layer,user,options) }

    it "converts to image" do
      expect(manifest.images.count).to eql(5)
      expect(image.layers.count).to eql(2)
      new_image = actor.make_layer_an_image
      expect(new_image).to be_a(Trifle::IIIFImage)
      expect(new_image).to be_persisted
      manifest.reload
      expect(manifest.images.count).to eql(6)
      expect(manifest.images.map(&:id)).to include(new_image.id)
      expect(new_image.title).to eql(layer.title)
      expect(new_image.description).to eql(layer.description)
      expect(new_image.image_location).to eql(layer.image_location)
      expect(new_image.image_source).to eql(layer.image_source)
      expect(new_image.width).to eql(layer.width)
      expect(new_image.height).to eql(layer.height)
      expect(new_image.local_ark).to be_present

      image.reload
      expect(image.layers.count).to eql(1)
      expect(image.layers.map(&:id)).not_to include(layer.id)
    end
  end

end