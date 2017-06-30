require 'rails_helper'

RSpec.describe Trifle::IIIFAnnotationList do
  describe "#destroy" do
    let!(:annotation_list) { FactoryGirl.create(:iiifannotationlist, :with_manifest)}
    let!(:image) { annotation_list.parent }
    it "removes list from canvas" do
      expect(image.annotation_lists).not_to be_empty
      annotation_list.destroy
      expect(image.reload.annotation_lists).to be_empty
    end
  end
  
  describe "#as_json" do
    let(:annotation_list) { FactoryGirl.create(:iiifannotationlist, :with_image, :with_annotations)}
    let(:json) { annotation_list.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end
  
  describe "#from_params" do
    let(:annotation_list) { FactoryGirl.create(:iiifannotationlist, :with_image, :with_annotations)}
    it "can read from as_json output" do
      new_list = Trifle::IIIFAnnotationList.new(annotation_list.as_json)
      expect(new_list.id).to eql(annotation_list.id)
      expect(new_list.title).to eql(annotation_list.title)
      expect(new_list.annotations).to all( be_a(Trifle::IIIFAnnotation) )
    end
    it "can read from to_iiif output" do
      new_list = Trifle::IIIFAnnotationList.new(JSON.parse(annotation_list.to_iiif.to_json))
      expect(new_list.id).to eql(annotation_list.id)
      expect(new_list.title).to eql(annotation_list.title)
      expect(new_list.annotations).to all( be_a(Trifle::IIIFAnnotation) )
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
    let(:annotation_list) { FactoryGirl.create(:iiifannotationlist, :with_manifest)}
    before { File.unlink('/tmp/test-minter-state_other') if File.exists?('/tmp/test-minter-state_other') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:id) { annotation_list.id }
    it "includes image id" do
      s = id.split('_')
      expect(s.length).to eql(2)
      expect(s[0]).to eql(annotation_list.parent.id)
      expect(s[1]).to start_with('t0t')
    end
  end  
end
