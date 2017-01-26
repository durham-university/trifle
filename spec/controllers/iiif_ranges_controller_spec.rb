require 'rails_helper'

RSpec.describe Trifle::IIIFRangesController, type: :controller do

  let(:range) { FactoryGirl.create(:iiifrange,:with_manifest,:with_canvases,:with_sub_range) }
  let(:manifest) { range.manifest }
  let(:new_canvas) { 
    FactoryGirl.create(:iiifimage).tap do |img|
      manifest.ordered_members << img
      manifest.save
    end
  }
  
  let(:range_params) { { title: 'new title', canvas_ids: [new_canvas.id] } }

  routes { Trifle::Engine.routes }
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    
    describe "PUT #update" do
      it "sets values and canvas ids" do
        put :update, id: range.id, iiif_range: range_params, iiif_manifest_id: 'dummy'
        reloaded = Trifle::IIIFRange.find(range.id)
        expect(reloaded.title).to eql('new title')
        expect(reloaded.sub_ranges).not_to be_empty
        expect(reloaded.canvases.map(&:id)).to eql([new_canvas.id])
      end      
    end
    
    describe "POST #create" do
      context "within manifest" do
        it "creates the range with canvas ids" do
          manifest_range_count = manifest.ranges.count
          post :create, iiif_range: range_params, iiif_manifest_id: manifest.id
          manifest.reload
          expect(manifest.ranges.count).to eql(manifest_range_count+1)
          new_range = manifest.ranges.find do |s| s.title==range_params[:title] end
          expect(new_range).to be_present
          expect(new_range.canvases).not_to be_empty
        end
      end
      context "within another range" do
        let(:parent_range) { manifest.ranges.first }
        it "creates the range with canvas ids" do
          parent_range_count = parent_range.sub_ranges.count
          post :create, iiif_range: range_params, iiif_range_id: parent_range.id, iiif_manifest_id: 'dummy'
          reloaded = Trifle::IIIFRange.find(parent_range.id)
          expect(reloaded.sub_ranges.count).to eql(parent_range_count+1)
          new_range = reloaded.sub_ranges.find do |s| s.title==range_params[:title] end
          expect(new_range).to be_present
          expect(new_range.canvases).not_to be_empty
        end
      end
    end
  end
end