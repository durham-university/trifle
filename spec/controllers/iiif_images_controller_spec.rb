require 'rails_helper'

RSpec.describe Trifle::IIIFImagesController, type: :controller do

  routes { Trifle::Engine.routes }
  
  context "with anonymous user" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_images) }
    let(:image) { manifest.images.first }
    describe "GET #show_iiif" do
      it "renders manifest json" do
        expect_any_instance_of(Trifle::IIIFImage).to receive(:to_iiif).and_call_original
        get :show_iiif, id: image.id, iiif_manifest_id: manifest.id
        expect(JSON.parse(response.body)).to be_a(Hash)
        expect(response.body).to include(image.image_location)
      end
    end
    
    describe "GET #show_annotation_iiif" do
      it "renders sequence json" do
        expect_any_instance_of(Trifle::IIIFImage).to receive(:iiif_annotation).and_call_original
        get :show_annotation_iiif, id: image.id, iiif_manifest_id: manifest.id
        expect(JSON.parse(response.body)).to be_a(Hash)
        expect(response.body).to include(image.image_location)
      end
    end    
  end
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
        
    describe "GET #all_annotations" do
      let(:list) { FactoryGirl.create(:iiifannotationlist,:with_annotations,:with_manifest) }
      let(:image) { list.parent }
      let(:manifest) { list.manifest }
      
      it "returns all annotations" do
        get :all_annotations, id: image.id, iiif_manifest_id: manifest.id
        expect(JSON.parse(response.body)).to be_a(Array)
        expect(response.body).to include(list.annotations.first.content)
      end
      
    end
  end
end