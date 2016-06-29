require 'rails_helper'

RSpec.describe Trifle::IIIFAnnotationList do
  let(:annotation_list) { FactoryGirl.build(:iiifannotationlist)}
  describe "#as_json" do
    let(:json) { annotation_list.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end  
  
  describe "#to_iiif" do
    let(:annotation_list) { FactoryGirl.create(:iiifannotationlist, :with_manifest, :with_annotations)}
    let(:json) { annotation_list.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['label']).to eql(annotation_list.title)
      expect(json['@type']).to eql('sc:AnnotationList')
      expect(json['resources']).to be_a(Array)
    end
  end

  describe "id minting" do
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk'}) }
    let(:id) { annotation_list.assign_id }
    it "uses generic minter" do
      expect(id).to start_with('t0t')
    end
  end  
end
