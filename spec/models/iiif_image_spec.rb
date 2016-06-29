require 'rails_helper'

RSpec.describe Trifle::IIIFImage do
  let(:image) { FactoryGirl.create(:iiifimage, :with_manifest)}
  describe "#as_json" do
    let(:json) { image.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end  
  
  describe "#to_iiif" do
    before { image.save }
    let(:json) { image.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['label']).to eql(image.title)
      expect(json['@type']).to eql('sc:Canvas')
      expect(json['width']).to be_present
      expect(json['height']).to be_present
      expect(json['images']).to be_a(Array)
    end
  end

  describe "id minting" do
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk'}) }
    let(:image) { FactoryGirl.build(:iiifimage)}
    let(:id) { image.assign_id }
    it "uses generic minter" do
      expect(id).to start_with('t0t')
    end
  end  

end
