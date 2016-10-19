require 'rails_helper'

RSpec.describe Trifle::IIIFAnnotation do
  let(:annotation) { FactoryGirl.build(:iiifannotation)}
  describe "#as_json" do
    let(:json) { annotation.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end  
  
  describe "#to_iiif" do
    let(:annotation) { FactoryGirl.create(:iiifannotation,:with_manifest)}
    let(:json) { annotation.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['@type']).to eql('oa:Annotation')
      expect(json['motivation']).to eql('sc:painting')
      expect(json['on']['@type']).to eql('oa:SpecificResource')
      expect(json['on']['full']).to be_present
      expect(json['on']['selector']['@type']).to eql('oa:FragmentSelector')
      expect(json['on']['selector']['value']).to be_present
      expect(json['resource']['@type']).to eql('dctypes:Text')
      expect(json['resource']['label']).to eql(annotation.title)
      expect(json['resource']['format']).to eql(annotation.format)
      expect(json['resource']['chars']).to eql(annotation.content)
    end
  end

  describe "id minting" do
    before { File.unlink('/tmp/test-minter-state_other') if File.exists?('/tmp/test-minter-state_other') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:id) { annotation.assign_id }
    it "uses generic minter" do
      expect(id).to start_with('t0t')
    end
  end  

end
