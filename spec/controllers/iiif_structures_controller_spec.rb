require 'rails_helper'

RSpec.describe Trifle::IIIFStructuresController, type: :controller do

  let(:structure) { FactoryGirl.create(:iiifstructure,:with_manifest,:with_canvases,:with_sub_structure) }
  let(:manifest) { structure.manifest }
  let(:new_canvas) { 
    FactoryGirl.create(:iiifimage).tap do |img|
      manifest.ordered_members << img
      manifest.save
    end
  }
  
  let(:structure_params) { { title: 'new title', canvas_ids: [new_canvas.id] } }

  routes { Trifle::Engine.routes }
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    
    describe "PUT #update" do
      it "sets values and canvas ids" do
        put :update, id: structure.id, iiif_structure: structure_params
        structure.reload
        expect(structure.title).to eql('new title')
        expect(structure.sub_structures).not_to be_empty
        expect(structure.canvases.map(&:id)).to eql([new_canvas.id])
      end      
    end
    
    describe "POST #create" do
      context "within manifest" do
        it "creates the structure with canvas ids" do
          manifest_structure_count = manifest.structures.count
          post :create, iiif_structure: structure_params, iiif_manifest_id: manifest.id
          manifest.reload
          expect(manifest.structures.count).to eql(manifest_structure_count+1)
          new_structure = manifest.structures.find do |s| s.title==structure_params[:title] end
          expect(new_structure).to be_present
          expect(new_structure.canvases).not_to be_empty
        end
      end
      context "within another structure" do
        let(:parent_structure) { manifest.structures.first }
        it "creates the structure with canvas ids" do
          parent_structure_count = parent_structure.sub_structures.count
          post :create, iiif_structure: structure_params, iiif_structure_id: parent_structure.id
          parent_structure.reload
          expect(parent_structure.sub_structures.count).to eql(parent_structure_count+1)
          new_structure = parent_structure.sub_structures.find do |s| s.title==structure_params[:title] end
          expect(new_structure).to be_present
          expect(new_structure.canvases).not_to be_empty
        end
      end
    end
  end
end