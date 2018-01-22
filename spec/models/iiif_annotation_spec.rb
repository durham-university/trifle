require 'rails_helper'

RSpec.describe Trifle::IIIFAnnotation do
  describe "#as_json" do
    let(:annotation) { FactoryGirl.create(:iiifannotation, :with_image)}
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

    it "wraps on in an arroy with oa:Choice type" do
      annotation.selector = "{\"@type\":\"oa:Choice\",\"default\":{\"@type\":\"oa:FragmentSelector\",\"value\":\"xywh=100,100,200,80\"},\"item\":{\"@type\":\"oa:SvgSelector\",\"value\":\"<svg></svg>\"}}"
      expect(json['on']).to be_a(Array)
      expect(json['on'][0]['selector']['default']['@type']).to eql('oa:FragmentSelector')
      expect(json['on'][0]['selector']['item']['@type']).to eql('oa:SvgSelector')
    end
  end

  describe "id minting" do
    let(:annotation) { FactoryGirl.create(:iiifannotation,:with_manifest)}
    before { File.unlink('/tmp/test-minter-state_other') if File.exists?('/tmp/test-minter-state_other') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:id) { annotation.id }
    it "includes image id" do
      s = id.split('_')
      expect(s.length).to eql(2)
      expect(s[0]).to eql(annotation.on_image.id)
      expect(s[1]).to start_with('t0t')
    end
  end  

  describe "#from_params" do
    let(:annotation) { FactoryGirl.create(:iiifannotation, :with_image)}
    it "can read from as_json output" do
      new_anno = Trifle::IIIFAnnotation.new(annotation.as_json)
      expect(new_anno.id).to eql(annotation.id)
      expect(new_anno.title).to eql(annotation.title)
      expect(new_anno.format).to eql(annotation.format)
      expect(new_anno.language).to eql(annotation.language)
      expect(new_anno.content).to eql(annotation.content)
      expect(new_anno.selector).to eql(annotation.selector)
    end
    it "can read from to_iiif output" do
      new_anno = Trifle::IIIFAnnotation.new(JSON.parse(annotation.to_iiif.to_json))
      expect(new_anno.id).to eql(annotation.id)
      expect(new_anno.title).to eql(annotation.title)
      expect(new_anno.format).to eql(annotation.format)
      expect(new_anno.language).to eql(annotation.language)
      expect(new_anno.content).to eql(annotation.content)
      expect(new_anno.selector).to eql(annotation.selector)
    end
    it "works with oa:Choice selectors" do
      annotation.selector = "{\"@type\":\"oa:Choice\",\"default\":{\"@type\":\"oa:FragmentSelector\",\"value\":\"xywh=176,355,542,45\"},\"item\":{\"@type\":\"oa:SvgSelector\",\"value\":\"\\u003csvg xmlns='http://www.w3.org/2000/svg'\\u003e\\u003c/svg\\u003e\"}}"
      new_anno = Trifle::IIIFAnnotation.new(JSON.parse(annotation.to_iiif.to_json))
      expect(new_anno.selector).to eql(annotation.selector)      
    end
  end

end
