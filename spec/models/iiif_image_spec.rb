require 'rails_helper'

RSpec.describe Trifle::IIIFImage do
  before { allow(Trifle::IIIFImage).to receive(:ark_naan).and_return('12345') }
  before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
  let(:image) { FactoryGirl.create(:iiifimage, :with_manifest)}
  describe "#as_json" do
    let(:json) { image.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
      expect(json['serialised_annotations']).to be_nil
      expect(json['serialised_layers']).to be_nil
    end
  end  
  
  describe "#to_iiif" do
    let(:image) { FactoryGirl.create(:iiifimage, :with_manifest, :with_layers, source_record: 'schmit:ark:/12345/test', description: "test_description" )}
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
      expect(json['images'][0]['resource']['service']['@context']).to be_present
      expect(json['images'][1]['@id']).to end_with(image.layers[0].id)
      expect(json['related']['@id']).to eql('http://www.example.com/xtf/view?docId=12345_test.xml')
      expect(json['related']['label']).to be_present
      expect(json['description']).to eql('test_description')
    end
  end
  
  describe "#to_solr" do
    let(:solr_doc) { image.to_solr }
    let(:profile) { JSON.parse(solr_doc['object_profile_ssm']) }
    context "with annotations" do
      let(:annotation_list) { FactoryGirl.build(:iiifannotationlist, :with_annotations, parent: image) }
      before {
        image.annotation_lists.push(annotation_list)
        annotation_list.save
      }
      it "adds ranges to object profile" do
        expect(profile['serialised_annotations']).to be_present
      end
    end
    context "with layers" do
      let(:image) { FactoryGirl.create(:iiifimage, :with_manifest, :with_layers)}
      it "adds layers to object profile" do
        expect(profile['serialised_layers']).to be_present
      end
    end
  end

  describe "id minting" do
    before { File.unlink('/tmp/test-minter-state_other') if File.exists?('/tmp/test-minter-state_other') }
    let(:image) { FactoryGirl.build(:iiifimage)}
    let(:id) { image.assign_id }
    it "uses generic minter" do
      expect(id).to start_with('t0t')
    end
  end  
  
  describe "child arks" do
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

  describe "persisting annotations" do
    let(:test_string) { "\xE2\x80\x9C\xC3\xA4".force_encoding("UTF-8") }
    let(:image) { annotation_list.parent }
    let(:annotation_list) { annotation.parent }
    let!(:annotation) { FactoryGirl.create(:iiifannotation, :with_image, content: test_string) }
    it "supports special characters" do
      image.reload
      expect(image.annotation_lists.first.annotations.first.content).to eql(test_string)
    end
  end

  describe "source record" do
    # iiif_manifest_spec has more source record tests, manifest and collection share the same concern
    let(:image) { FactoryGirl.build(:iiifimage, source_record: 'schmit:ark:/12345/testid#subid') }    
    describe "#source_type" do
      it "returns the source type" do
        expect(image.source_type).to eql('schmit')
      end
    end
    describe "#source_url" do
      it "retuns a schmit link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_base_url' => 'http://www.example.com/schmit'})
        expect(image.source_url).to eql('http://www.example.com/schmit/catalogues/testid#subid')
      end
    end
    describe "#public_source_link" do
      it "returns a iiif link to xtf" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        link = image.public_source_link
        expect(link['@id']).to eql('http://www.example.com/xtf/view?docId=12345_testid.xml#subid')
        expect(link['label']).to be_present
      end
      it "returns nil if no link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        image.source_record = nil
        expect(image.public_source_link).to be_nil
      end
    end
    describe "::find_from_source" do
      let!(:image1) { FactoryGirl.create(:iiifimage, :with_manifest, source_record: 'schmit:ark:/12345/testid1#subid\\1') }    
      let!(:image2) { FactoryGirl.create(:iiifimage, :with_manifest, source_record: 'schmit:ark:/12345/testid1#subid\\2') }    
      let!(:image3) { FactoryGirl.create(:iiifimage, :with_manifest, source_record: 'schmit:ark:/12345/testid2#subid"1"') }    
      
      context "prefix search" do
        let(:result1) { Trifle::IIIFImage.find_from_source('schmit:ark:/12345/testid1#')}
        let(:result2) { Trifle::IIIFImage.find_from_source('schmit:ark:/12345/testid2#')}
        let(:result3) { Trifle::IIIFImage.find_from_source('schmit:ark:/12345/testid\\2')}
        it "finds correct manifests" do
          expect(result1.map(&:id)).to match_array([image1.id,image2.id])
          expect(result2.map(&:id)).to match_array([image3.id])
          expect(result3.empty?).to eql(true)
        end
      end
    end
  end

  describe "#to_millennium" do
    # iiif_manifest_spec has some more millennium linking related tests
    before { allow(DurhamRails::LibrarySystems::Millennium).to receive(:connection).and_return(mock_millennium)}
    let(:mock_millennium) { 
      double('mock_millennium').tap do |m| allow(m).to receive(:record).with('12345').and_return(mock_record) end
    }
    let(:mock_record) {
      double('mock_record').tap do |m| allow(m).to receive(:holdings).and_return([double('mock_holding',holding_id: 'test', call_no: 'testcallno')]) end
    }    
    let(:image) { FactoryGirl.create(:iiifimage, :with_manifest) } # need ark and id in image
    it "returns nil when source is not in millennium" do
      image.source_record = nil
      expect(image.to_millennium).to be_nil
      image.source_record = "schmit:test"
      expect(image.to_millennium).to be_nil
    end
    it "returns millennium records" do
      image.source_record = "millennium:12345#test"
      mil = image.to_millennium
#      expect(mil['12345'][0].to_s).to eql("533    $8 1\\c $3 testcallno $a Digital image $c Durham University $5 UkDhU ")
#      expect(mil['12345'][1].to_s).to eql("856 41 $8 1\\c $3 testcallno $u https://n2t.durham.ac.uk/#{image.parent.local_ark}/#{image.id}.html $y Online version $x Injected by Trifle ")
      expect(mil['12345'][0].to_s).to eql("856 41 $3 testcallno $u https://n2t.durham.ac.uk/#{image.parent.local_ark}/#{image.id}.html $y Online version $x Injected by Trifle ")
    end
  end  
end
