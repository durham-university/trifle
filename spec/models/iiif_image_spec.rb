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
    let(:image) { FactoryGirl.create(:iiifimage, :with_manifest, source_record: 'schmit:ark:/12345/test', description: "test_description" )}
    before { 
      allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
      image.save 
    }
    let(:json) { image.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['label']).to eql(image.title)
      expect(json['@type']).to eql('sc:Canvas')
      expect(json['width']).to be_present
      expect(json['height']).to be_present
      expect(json['images']).to be_a(Array)
      expect(json['related']['@id']).to eql('http://www.example.com/xtf/view?docId=12345_test.xml')
      expect(json['related']['label']).to be_present
      expect(json['description']).to eql('test_description')
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
  
  describe "child arks" do
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:manifest) { FactoryGirl.create(:iiifmanifest) }
    let(:image) {
      manifest.ordered_members << FactoryGirl.create(:iiifimage)
      manifest.save
      manifest.images.first.reload
    }
    let(:ark) { image.local_ark }
    
    it "has a child ark" do
      image
      expect(ark).to match(/^ark:\/12345\/[0-9a-z]+\/[0-9a-z]+$/)
      expect(ark).to start_with(manifest.local_ark)
    end
  end

end
