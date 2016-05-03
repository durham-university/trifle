require 'rails_helper'

RSpec.describe Trifle::IIIFManifestsController, type: :controller do

  let(:collection) { FactoryGirl.create(:iiifcollection) }
  let(:manifest) { FactoryGirl.create(:iiifmanifest) }
  let(:deposit_items) { [{'source_path' => 'http://localhost/dummy1', 'title' => '1'}, {'source_path' => 'http://localhost/dummy2', 'title' => '2'}] }

  routes { Trifle::Engine.routes }
  
  context "with anonymous user" do
    before {
      expect_any_instance_of(Trifle::DepositJob).not_to receive(:queue_job)
    }
    describe "POST #deposit_images" do
      it "fails authentication" do
        # not receive queue_job in before block
        post :deposit_images, id: manifest.id, deposit_items: deposit_items
      end
    end
    
    describe "POST #create_and_deposit_images" do
      it "fails authentication" do
        expect {
          # not receive queue_job in before block
          post :create_and_deposit_images, 
                iiif_collection_id: collection.id, 
                deposit_items: deposit_items, 
                iiif_manifest: { source_record: 'schmit:ark:/12345/testid#subid' }, 
                format: 'json'
        }.not_to change(Trifle::IIIFManifest, :count)
      end
    end
    
    describe "POST #refresh_from_source" do
      it "fails authentication" do 
        expect_any_instance_of(Trifle::IIIFManifest).not_to receive(:refresh_from_source)
        expect(Schmit::API::Catalogue).not_to receive(:try_find)
        post :refresh_from_source, id: manifest.id
      end
    end    
    
    describe "GET #show_iiif" do
      let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_images) }
      it "renders manifest json" do
        expect_any_instance_of(Trifle::IIIFManifest).to receive(:to_iiif).and_call_original
        get :show_iiif, id: manifest.id
        expect(JSON.parse(response.body)).to be_a(Hash)
        expect(response.body).to include(manifest.images.first.image_location)
      end
    end
  end
  
  context "with api user" do
    let(:user) { FactoryGirl.create(:user,:api) }
    before { sign_in user }
    
    describe "GET #index with in_source set" do
      let!(:manifest1) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid1#subid') }
      let!(:manifest2) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid2#subid') }
      it "returns only manifests in source with prefix query" do
        expect(Trifle::IIIFManifest).to receive(:find_from_source).and_call_original
        get :index, in_source: 'schmit:ark:/12345/testid1', format: 'json'
        json = JSON.parse(response.body)
        expect(json['resources'].length).to eql(1)
        expect(json['resources'].first['id']).to eql(manifest1.id)
      end
      it "returns only manifests in source with exact query" do
        get :index, in_source: 'schmit:ark:/12345/testid1#subid', in_source_prefix: 'false', format: 'json'
        json = JSON.parse(response.body)
        expect(json['resources'].length).to eql(1)
        expect(json['resources'].first['id']).to eql(manifest1.id)
        
        get :index, in_source: 'schmit:ark:/12345/testid1', in_source_prefix: 'false', format: 'json'
        json = JSON.parse(response.body)
        expect(json['resources'].length).to eql(0)
      end
    end
    
    describe "POST #deposit_images" do
      it "queues a job with deposit items" do
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job) { |job|
            expect(job.deposit_items).to eql(deposit_items)
            expect(job.resource.id).to eql(manifest.id)
          } .and_return(true)
        post :deposit_images, id: manifest.id, deposit_items: deposit_items
      end
      it "sanitises deposit_items" do
        deposit_items << '/tmp/testfile'
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job) { |job|
            expect(job.deposit_items).not_to include('/tmp/testfile')
          } .and_return(true)
        post :deposit_images, id: manifest.id, deposit_items: deposit_items        
      end
      it "returns json" do
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job).and_return(true)
        post :deposit_images, id: manifest.id, deposit_items: deposit_items, format: 'json'
        parsed = JSON.parse(response.body)
        expect(parsed['resource']['id']).to eql(manifest.id)
        expect(parsed['status']).to eql('ok')
      end
      it "returns error messages" do
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job) { raise 'test error message' }
        post :deposit_images, id: manifest.id, deposit_items: deposit_items, format: 'json'
        parsed = JSON.parse(response.body)
        expect(parsed['resource']['id']).to eql(manifest.id)
        expect(parsed['status']).to eql('error')
        expect(parsed['message']).to include('test error message')
      end
    end
    
    describe "POST #create_and_deposit_images" do
      it "creates a new manifest and calls deposit_images" do
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job) { |job|
            expect(job.deposit_items).to eql(deposit_items)
            expect(job.resource.id).to be_present
          } .and_return(true)
        expect(collection.ordered_members.to_a).to be_empty
        expect_any_instance_of(Trifle::IIIFManifest).to receive(:refresh_from_source) do |instance|
          expect(instance.source_record).to eql('schmit:ark:/12345/testid#subid')
          instance.description = 'from source'
        end
        expect {
          post :create_and_deposit_images, 
                iiif_collection_id: collection.id, 
                deposit_items: deposit_items, 
                iiif_manifest: { source_record: 'schmit:ark:/12345/testid#subid' }, 
                format: 'json'
        }.to change(Trifle::IIIFManifest, :count).by(1)
        
        parsed = JSON.parse(response.body)
        expect(parsed['resource']['id']).to be_present
        expect(parsed['resource']['description']).to eql('from source')
        expect(parsed['status']).to eql('ok')
        
        expect(collection.reload.ordered_members.to_a.map(&:id)).to eql([parsed['resource']['id']])
        expect(Trifle::IIIFManifest.all_in_collection(collection).map(&:id)).to eql([parsed['resource']['id']])
      end
    end    
  end
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
        
    describe "POST #refresh_from_source" do
      let(:manifest) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid#subid') }
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
      it "refreshes resource from source" do
        expect(Schmit::API::Catalogue).to receive(:try_find).with('ark:/12345/testid').and_return(manifest_api)
        post :refresh_from_source, id: manifest.id
        manifest.reload
        expect(manifest.title).to eql('new title')
        expect(manifest.date_published).to eql('new date')
        expect(manifest.description).to eql('new scopecontent')
      end
    end    
  end
  

end