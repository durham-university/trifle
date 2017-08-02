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
    
    describe "POST #refresh_from_source" do
      it "fails authentication" do 
        expect_any_instance_of(Trifle::IIIFImage).not_to receive(:refresh_from_source)
        expect(Schmit::API::Catalogue).not_to receive(:try_find)
        post :refresh_from_source, id: image.id, iiif_manifest_id: manifest.id
      end
    end        
  end
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_images) }
    let(:image) { manifest.images.first }
        
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
    
    describe "PUT #update" do
      it "marks containing manifest dirty" do
        manifest.set_clean
        manifest.save
        put :update, id: image.id, iiif_image: {title: 'changed'}, iiif_manifest_id: 'dummy'
        expect(manifest.reload).to be_dirty
      end
    end
    describe "POST #create" do
      it "marks containing manifest dirty" do
        manifest.set_clean
        manifest.save
        post :create, iiif_manifest_id: manifest.id, iiif_image: {title: 'new image'}
        expect(manifest.reload).to be_dirty
      end
    end
    
    describe "POST #refresh_from_source" do
      let(:image) { FactoryGirl.create(:iiifimage, source_record: 'schmit:ark:/12345/testid#subid') }
      let(:manifest) { FactoryGirl.create(:iiifmanifest, ordered_members: [image])}
      it "refreshes resource from source and starts a publish job" do
        expect(image).to receive(:refresh_from_source).and_return(true)
        expect(controller).to receive(:set_refresh_from_source_resource) do controller.send(:set_resource,image) end
        expect(Trifle.queue).to receive(:push).with(kind_of(Trifle::PublishJob)) do |job|
          expect(job.resource_id).to eql(manifest.id) # job posted for manifest
        end
        post :refresh_from_source, id: image.id, iiif_manifest_id: manifest.id
      end
    end        
  end

  context "with api user" do
    let(:user) { FactoryGirl.create(:user,:api) }
    before { sign_in user }
    
    describe "GET #index with in_source set" do
      let!(:manifest1) { FactoryGirl.create(:iiifmanifest, :with_images) }
      let!(:manifest2) { FactoryGirl.create(:iiifmanifest, :with_images) }
      before {
        manifest1.images[0].source_record = 'schmit:ark:/12345/test#abc'
        manifest1.images[0].save
        manifest1.images[1].source_record = 'schmit:ark:/12345/moo#ghi'
        manifest1.images[1].save
        manifest2.images[1].source_record = 'schmit:ark:/12345/test#def'
        manifest2.images[1].save
      }
      it "returns only images in source with prefix query" do
        expect(Trifle::IIIFImage).to receive(:find_from_source).and_call_original
        get :index, in_source: 'schmit:ark:/12345/test', format: 'json'
        json = JSON.parse(response.body)
        expect(json['resources'].map do |r| r['id'] end).to match_array([manifest1.images[0].id, manifest2.images[1].id])
      end
      it "returns only images in source with exact query" do
        get :index, in_source: 'schmit:ark:/12345/test#abc', in_source_prefix: 'false', format: 'json'
        json = JSON.parse(response.body)
        expect(json['resources'].length).to eql(1)
        expect(json['resources'].first['id']).to eql(manifest1.images[0].id)
        
        get :index, in_source: 'schmit:ark:/12345/test', in_source_prefix: 'false', format: 'json'
        json = JSON.parse(response.body)
        expect(json['resources'].length).to eql(0)
      end
    end
  end
  
  describe "#set_new_resource" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest) }
    let(:user) { FactoryGirl.create(:user,:admin) }
    before {
      allow(Trifle).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['11111','22222','33333']})
      manifest.identifier = ['ark:/22222/manifest']
      manifest.save
      sign_in user
    }
    it "sets parent naan" do
      post :create, iiif_manifest_id: manifest.id, iiif_image: { title: 'created manifest' }      
      expect(assigns(:resource).local_ark_naan).to eql('22222')
    end
  end
  
end
