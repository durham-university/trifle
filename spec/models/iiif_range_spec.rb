require 'rails_helper'

RSpec.describe Trifle::IIIFRange do
  let(:range) { FactoryGirl.build(:iiifrange)}
  
  describe "#destroy" do
    let!(:range) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range)}
    let!(:canvases) { range.canvases.to_a }
    let!(:sub_ranges) { range.sub_ranges.to_a }
    it "destroys also sub_ranges" do
      expect(sub_ranges).not_to be_empty
      range.destroy
      expect {
        Trifle::IIIFRange.find(sub_ranges.first.id)
      }.to raise_error(Ldp::Gone)
    end
    it "doesn't destroy canvases" do
      expect(canvases).not_to be_empty
      range.destroy
      expect(Trifle::IIIFImage.find(canvases.first.id)).to be_a(Trifle::IIIFImage)
    end
  end
  
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
    let(:json) { range.to_iiif(iiif_version: version).to_ordered_hash }
    let(:sub_json) { range.sub_ranges.first.to_iiif(iiif_version: version).to_ordered_hash }
    describe "version 1" do
      let(:version){'1.0'}
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
    describe "version 2" do
      let(:version){'2.0'}
      it "sets properties" do
        expect(json['label']).to eql(range.title)
        expect(json['@type']).to eql('sc:Range')
        expect(json['viewingHint']).to eql('top')
        expect(json['canvases']).to be_a(Array)
        expect(json['canvases']).not_to be_empty
        expect(json['ranges']).to be_a(Array)
        expect(json['ranges']).not_to be_empty
        
        expect(sub_json['@type']).to eql('sc:Range')
      end
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
  
  describe "id minting" do
    before { File.unlink('/tmp/test-minter-state_other') if File.exists?('/tmp/test-minter-state_other') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:id) { range.assign_id }
    it "uses generic minter" do
      expect(id).to start_with('t0t')
    end
  end  

end
