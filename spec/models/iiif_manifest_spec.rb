require 'rails_helper'

RSpec.describe Trifle::IIIFManifest do
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  describe "#add_deposited_image" do
    let(:image) { FactoryGirl.build(:iiifimage, title: 'dummy image') }
    it "adds the image to ordered_members" do
      manifest.add_deposited_image(image)
      expect(manifest.reload.ordered_members.to_a.map(&:title)).to eql(['dummy image'])
    end
  end
  
  describe "#default_container_location!" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest, image_container_location: nil) }
    it "doesn't do anything if already set" do
      manifest.image_container_location = 'dummy'
      manifest.default_container_location!
      expect(manifest.image_container_location).to eql('dummy')
    end
    
    context "with a persisted manifest and no ark" do
      before { manifest.save }
      it "sets the container_location to be the same as id" do
        manifest.default_container_location!
        expect(manifest.image_container_location).to eql("#{manifest.id[0..1]}/#{manifest.id[2..3]}/#{manifest.id[4..5]}/#{manifest.id}")
      end
    end
    context "with a new manifest" do
      before {
        allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345')
      }
      it "it reserves an ark and sets that as container_location" do
        manifest.default_container_location!
        manifest.save
        expect(manifest.image_container_location).to eql("12345/#{manifest.id[0..1]}/#{manifest.id[2..3]}/#{manifest.id[4..5]}/#{manifest.id}")
      end
    end
  end
  
  describe "#iiif_manifest" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest,:with_images,:with_range) }
    it "makes a valid iiif_manifest object" do
      m = manifest.iiif_manifest
      expect(m).to be_a(IIIF::Presentation::Manifest)
      json = m.to_json
      expect(json).to be_a(String)
      expect(json).to include(manifest.images.first.image_location)
      expect(json).to include(manifest.ranges.first.id)
    end
  end
  
  describe "#to_iiif" do
    it "calls #iiif_manifest" do
      expect(manifest).to receive(:iiif_manifest).and_return({test: 'foo'})
      expect(manifest.to_iiif).to eql({test: 'foo'})
    end
  end
  
  describe "#as_json" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest)}
    let(:json) { manifest.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
    context "with parent" do
      let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_parent)}
      it "sets parent_id" do
        expect(json['parent_id']).to be_present
      end
    end
    context "with include_children" do
      let(:manifest) { FactoryGirl.build(:iiifmanifest, :with_images )}
      let(:json) { manifest.as_json(include_children: true) }
      it "includes child objects" do
        expect(json['images'].length).to be > 0
      end
    end
  end  
  
  describe "#to_solr" do
    let(:solr_doc) { manifest.to_solr }
    context "with a parent" do
      let(:manifest) { FactoryGirl.create(:iiifcollection, :with_parent)}
      it "includes root collection id in solr" do
        expect(solr_doc[Solrizer.solr_name('root_collection_id', type: :symbol)]).to eql(manifest.root_collection.id)
      end
    end
    context "with a root object" do
      it "doesn't add solr field" do
        expect(solr_doc.key?(Solrizer.solr_name('root_collection_id', type: :symbol))).to eql(false)
      end
    end
  end  
  
  describe "source record" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest, source_record: 'schmit:ark:/12345/testid#subid') }    
    describe "#source_type" do
      it "returns the source type" do
        expect(manifest.source_type).to eql('schmit')
      end
    end
    describe "#source_identifier" do
      it "returns source identifier" do
        expect(manifest.source_identifier).to eql('ark:/12345/testid#subid')
      end
    end
    describe "#refresh_from_source" do
      it "calls schmit version" do
        expect(manifest).to receive('refresh_from_schmit_source')
        manifest.refresh_from_source
      end
      it "calls millenium version" do 
        manifest.source_record='millenium:test'
        expect(manifest).to receive('refresh_from_millenium_source')
        manifest.refresh_from_source        
      end
    end
    describe "#refresh_from_schmit_source" do
      let(:manifest_api) { 
        double('manifest_api_mock').tap do |mock|
          expect(mock).to receive(:xml_record).and_return(double('xml_record_mock').tap do |mock|
            expect(mock).to receive(:sub_item).with('subid').and_return(double('sub_record_mock').tap do |mock|
              allow(mock).to receive(:title_path).and_return('new title')
              allow(mock).to receive(:date).and_return('new date')
              allow(mock).to receive(:scopecontent).and_return('new scopecontent')
            end)
          end)
        end
      }
      
      it "fetches new information from source" do
        expect(Schmit::API::Catalogue).to receive(:try_find).with('ark:/12345/testid').and_return(manifest_api)
        manifest.refresh_from_schmit_source
        expect(manifest.title).to eql('new title')
        expect(manifest.date_published).to eql('new date')
        expect(manifest.description).to eql('new scopecontent')
      end
    end
    describe "::find_from_source" do
      let!(:manifest1) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid1#subid\\1') }    
      let!(:manifest2) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid1#subid\\2') }    
      let!(:manifest3) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid2#subid"1"') }    
      
      context "prefix search" do
        let(:result1) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid1#')}
        let(:result2) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid2#')}
        let(:result3) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid\\2')}
        it "finds correct manifests" do
          expect(result1.map(&:id)).to match_array([manifest1.id,manifest2.id])
          expect(result2.map(&:id)).to match_array([manifest3.id])
          expect(result3.empty?).to eql(true)
        end
      end
      
      context "exact search" do
        let(:result1) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid1#subid\\1',false)}
        let(:result2) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid2#subid"1"',false)}
        let(:result3) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid1#',false)}
        it "finds correct manifests" do
          expect(result1.map(&:id)).to match_array([manifest1.id])
          expect(result2.map(&:id)).to match_array([manifest3.id])
          expect(result3.empty?).to eql(true)
        end
      end
    end
  end
  
  describe "::all_in_collections" do
    let!(:root1) { FactoryGirl.create(:iiifcollection, ordered_members: [sub1, man1]) }
    let!(:sub1) { FactoryGirl.create(:iiifcollection, ordered_members: [man2])}
    let!(:root2) { FactoryGirl.create(:iiifcollection, ordered_members: [man3]) }
    let(:man1) { FactoryGirl.create(:iiifmanifest) }
    let(:man2) { FactoryGirl.create(:iiifmanifest) }
    let(:man3) { FactoryGirl.create(:iiifmanifest) }
    before { Trifle::IIIFManifest.all.each do |m| m.update_index end }
    let(:all) { Trifle::IIIFManifest.all_in_collection(root1) }
    it "returns all in specified collection" do
      expect(all.count).to eql(2)
      expect(all.map(&:id)).to match_array([man1.id,man2.id])
    end
  end  
end
