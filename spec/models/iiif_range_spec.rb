require 'rails_helper'

RSpec.describe Trifle::IIIFRange do
  let(:range) { FactoryGirl.build(:iiifrange)}
  describe "#as_json" do
    let(:json) { range.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end  
  
  describe "#sub_ranges" do
    let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    it "returns sub ranges" do
      expect(range.sub_ranges).not_to be_empty
      expect(range.sub_ranges).to all( be_a Trifle::IIIFRange )
    end
  end
  
  describe "#root_range" do
    let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    it "returns the root range" do
      expect(range.root_range.id).to eql(range.id)
      expect(range.sub_ranges.first.root_range.id).to eql(range.id)
    end
  end
  
  describe "#parent_range" do
    let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    it "returns the manifest" do
      expect(range.parent_range).to be_nil
      expect(range.sub_ranges.first.parent_range.id).to eql(range.id)
    end
  end
  
  describe "#manifest" do
    let(:manifest) { range.manifest }
    let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    it "returns the manifest" do
      expect(manifest).to be_a Trifle::IIIFManifest
      expect(range.sub_ranges.first.manifest.id).to eql(manifest.id)
    end
  end
  
  describe "#to_iiif" do
    let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    let(:json) { range.to_iiif.to_ordered_hash }
    let(:sub_json) { range.sub_ranges.first.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['label']).to eql(range.title)
      expect(json['@type']).to eql('sc:Range')
      expect(json['viewingHint']).to eql('top')
      expect(json['canvases']).to be_a(Array)
      expect(json['canvases']).not_to be_empty
      
      expect(sub_json['@type']).to eql('sc:Range')
      expect(sub_json['within']).to be_present
    end
  end
  
  describe "canvas methods" do
    let(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    
    describe "#canvases" do
      it "returns canvases" do
        expect(range.canvases.to_a).not_to be_empty
        expect(range.canvases.to_a).to all( be_a Trifle::IIIFImage )
      end
    end
    describe "#canvas_ids" do
      it "returns canvas ids" do
        expect(range.canvas_ids.to_a).not_to be_empty
        expect(range.canvas_ids.to_a).to eql(range.canvases.to_a.map(&:id))
      end
    end
    describe "#canvas_ids=" do
      let(:manifest) { range.manifest }
      let(:new_canvas) { 
        FactoryGirl.create(:iiifimage).tap do |img|
          manifest.ordered_members << img
          manifest.save
        end
      }
      it "sets canvases and doesn't clear anything else" do
        sub_range_count = range.sub_ranges.count
        expect(sub_range_count).to be > 0
        range.canvas_ids = [new_canvas.id]
        expect(range.sub_ranges.count).to eql(sub_range_count)
        expect(range.canvas_ids).to eql([new_canvas.id])
      end
    end
  end

end
