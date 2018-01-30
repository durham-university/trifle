require 'rails_helper'

RSpec.describe Trifle::IIIFLayer do
  before { allow(Trifle::IIIFImage).to receive(:ark_naan).and_return('12345') }
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
  let(:image) { FactoryGirl.create(:iiifimage, :with_layers)}
  let(:layer) { image.layers[0] }

  describe "persisting" do
    let(:layer) { Trifle::IIIFLayer.find(image.layers.first.id) }
    it "saves and loads all fields" do
      expect(layer.title).to be_present
      expect(layer.description).to be_present
      expect(layer.width).to be_present
      expect(layer.height).to be_present
      expect(layer.embed_xywh).to be_present
      expect(layer.image_source).to be_present
    end
  end

  describe "#destroy" do
    it "removes list from image" do
      expect(image.layers.length).to eql(2)
      layer.destroy
      expect(image.reload.layers.length).to eql(1)
    end
  end

  describe "#as_json" do
    let(:json) { layer.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
      expect(json['width']).to be_present
    end
  end  
  
  describe "#to_iiif" do
    let(:json) { layer.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['label']).to eql(layer.title)
      expect(json['@type']).to eql('oa:Annotation')
      expect(json['on']).to end_with("#{image.id}#xywh=#{layer.embed_xywh}")
      expect(json['resource']['width']).to eql(layer.width.to_i)
      expect(json['resource']['height']).to eql(layer.height.to_i)
      expect(json['resource']['service']['@id']).to end_with(layer.image_location)
    end
  end

  describe "#from_params" do
    let(:read) { Trifle::IIIFLayer.new(image, JSON.parse(layer.to_iiif.to_json)) }
    it "reads all properties" do
      expect(read.title).to eql(layer.title)
      expect(read.description).to eql(layer.description)
      expect(read.width).to eql(layer.width.to_i)
      expect(read.height).to eql(layer.height.to_i)
      expect(read.image_location).to eql(layer.image_location)
      expect(read.embed_xywh).to eql(layer.embed_xywh)
      expect(read.id).to eql(layer.id)
    end
  end

  describe "id minting" do
    let(:id) { layer.id }
    it "includes image id" do
      expect(id).to start_with(image.id+"_")
    end
  end  


end