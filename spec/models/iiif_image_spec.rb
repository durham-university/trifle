require 'rails_helper'

RSpec.describe Trifle::IIIFImage do
  let(:image) { FactoryGirl.create(:iiifimage, :with_manifest)}
  describe "#as_json" do
    let(:json) { image.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
      expect(json['serialised_annotations']).to be_nil
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
  
  describe "#to_solr" do
    let(:solr_doc) { image.to_solr }
    context "with annotations" do
      let(:annotation_list) { FactoryGirl.build(:iiifannotationlist, :with_annotations, parent: image) }
      before {
        image.annotation_lists.push(annotation_list)
        annotation_list.save
      }
      it "adds ranges to object profile" do
        profile = JSON.parse(solr_doc['object_profile_ssm'])
        expect(profile['serialised_annotations']).to be_present
      end
    end
  end

  describe "id minting" do
    before { File.unlink('/tmp/test-minter-state_other') if File.exists?('/tmp/test-minter-state_other') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:image) { FactoryGirl.build(:iiifimage)}
    let(:id) { image.assign_id }
    it "uses generic minter" do
      expect(id).to start_with('t0t')
    end
  end  

end
