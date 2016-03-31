require 'rails_helper'

RSpec.describe Trifle::IIIFStructure do
  let(:structure) { FactoryGirl.build(:iiifstructure)}
  describe "#as_json" do
    let(:json) { structure.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
  end  
  
  describe "#sub_structures" do
    let(:structure) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure)}
    it "returns sub structures" do
      expect(structure.sub_structures).not_to be_empty
      expect(structure.sub_structures).to all( be_a Trifle::IIIFStructure )
    end
  end
  
  describe "#root_structure" do
    let(:structure) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure)}
    it "returns the root structure" do
      expect(structure.root_structure.id).to eql(structure.id)
      expect(structure.sub_structures.first.root_structure.id).to eql(structure.id)
    end
  end
  
  describe "#parent_structure" do
    let(:structure) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure)}
    it "returns the manifest" do
      expect(structure.parent_structure).to be_nil
      expect(structure.sub_structures.first.parent_structure.id).to eql(structure.id)
    end
  end
  
  describe "#manifest" do
    let(:manifest) { structure.manifest }
    let(:structure) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure)}
    it "returns the manifest" do
      expect(manifest).to be_a Trifle::IIIFManifest
      expect(structure.sub_structures.first.manifest.id).to eql(manifest.id)
    end
  end
  
  describe "#to_iiif" do
    let(:structure) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure)}
    let(:json) { structure.to_iiif.to_ordered_hash }
    let(:sub_json) { structure.sub_structures.first.to_iiif.to_ordered_hash }
    it "sets properties" do
      expect(json['label']).to eql(structure.title)
      expect(json['@type']).to eql('sc:Range')
      expect(json['viewingHint']).to eql('top')
      expect(json['canvases']).to be_a(Array)
      expect(json['canvases']).not_to be_empty
      
      expect(sub_json['@type']).to eql('sc:Range')
      expect(sub_json['within']).to be_present
    end
  end
  
  describe "canvas methods" do
    let(:structure) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure)}
    
    describe "#canvases" do
      it "returns canvases" do
        expect(structure.canvases.to_a).not_to be_empty
        expect(structure.canvases.to_a).to all( be_a Trifle::IIIFImage )
      end
    end
    describe "#canvas_ids" do
      it "returns canvas ids" do
        expect(structure.canvas_ids.to_a).not_to be_empty
        expect(structure.canvas_ids.to_a).to eql(structure.canvases.to_a.map(&:id))
      end
    end
    describe "#canvas_ids=" do
      let(:manifest) { structure.manifest }
      let(:new_canvas) { 
        FactoryGirl.create(:iiifimage).tap do |img|
          manifest.ordered_members << img
          manifest.save
        end
      }
      it "sets canvases and doesn't clear anything else" do
        sub_structure_count = structure.sub_structures.count
        expect(sub_structure_count).to be > 0
        structure.canvas_ids = [new_canvas.id]
        expect(structure.sub_structures.count).to eql(sub_structure_count)
        expect(structure.canvas_ids).to eql([new_canvas.id])
      end
    end
  end

end
