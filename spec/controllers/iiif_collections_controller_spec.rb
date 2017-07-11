require 'rails_helper'

RSpec.describe Trifle::IIIFCollectionsController, type: :controller do

  let(:collection) { FactoryGirl.create(:iiifcollection) }

  routes { Trifle::Engine.routes }
  
  
  before {
    allow(Trifle.queue).to receive(:push).and_return(true)
  }
  
  describe "#create" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before {
      allow(Trifle).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['11111','22222']})
      sign_in user
    }
    it "accepts ark_naan in params" do
      post :create, iiif_collection_id: collection.id, iiif_collection: { title: 'test title', ark_naan: '22222' }
      expect(assigns(:resource).local_ark_naan).to eql('22222')
    end
  end
  
  describe "#update" do
    describe "manifest reordering" do
      let(:user) { FactoryGirl.create(:user,:admin) }
      let(:collection) { FactoryGirl.create(:iiifcollection, :with_manifests, :with_sub_collections) }
      let(:manifest_ids) { collection.manifests.map(&:id) }
      before { sign_in user }
      it "can change ordering of manifests" do
        post :update, id: collection.id, iiif_collection: {manifest_order: "#{manifest_ids[1]}\n#{manifest_ids[0]}"}
        collection.reload
        expect(collection.manifests.map(&:id)).to eql([manifest_ids[1],manifest_ids[0]])
        expect(collection.sub_collections).not_to be_empty
      end
      it "raises error for invalid orderings" do
        expect {
          post :update, id: collection.id, iiif_collection: {manifest_order: "#{manifest_ids[0]}\n#{manifest_ids[0]}"}
        } .to raise_error('Invalid manifest list')
        collection.reload
        expect(collection.manifests.map(&:id)).to eql([manifest_ids[0],manifest_ids[1]])
      end
    end
    
    describe "sub collection reordering" do
      let(:user) { FactoryGirl.create(:user,:admin) }
      let(:collection) { FactoryGirl.create(:iiifcollection, :with_manifests, :with_sub_collections) }
      let(:sub_collection_ids) { collection.sub_collections.map(&:id) }
      before { sign_in user }
      it "can change ordering of sub collections" do
        post :update, id: collection.id, iiif_collection: {sub_collection_order: "#{sub_collection_ids[1]}\n#{sub_collection_ids[0]}"}
        collection.reload
        expect(collection.sub_collections.map(&:id)).to eql([sub_collection_ids[1],sub_collection_ids[0]])
        expect(collection.manifests).not_to be_empty
      end
      it "raises error for invalid orderings" do
        expect {
          post :update, id: collection.id, iiif_collection: {sub_collection_order: "#{sub_collection_ids[0]}\n#{sub_collection_ids[0]}"}
        } .to raise_error('Invalid sub collection list')
        collection.reload
        expect(collection.sub_collections.map(&:id)).to eql([sub_collection_ids[0],sub_collection_ids[1]])
      end
    end
  end
  
  describe "resource moving" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }

    let!(:collection1) { FactoryGirl.create(:iiifcollection, ordered_members: [collection2]) }
    let!(:collection2) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest1, manifest2]) }
    let!(:collection3) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest3, manifest4]) }
    let!(:collection4) { FactoryGirl.create(:iiifcollection) }
    let(:manifest1) { FactoryGirl.create(:iiifmanifest) }
    let(:manifest2) { FactoryGirl.create(:iiifmanifest) }
    let(:manifest3) { FactoryGirl.create(:iiifmanifest) }
    let(:manifest4) { FactoryGirl.create(:iiifmanifest) }
    before {
      collection1 ; collection2 ; collection3 ; collection4
      [manifest1,manifest2,manifest3,manifest4].each do |m| m.update_index end
    }
    
    let(:bucket) { [manifest1.id, manifest2.id, collection4.id] }
    let(:selection) { DurhamRails::SelectionBucket.new(bucket, nil) }
    before { allow(controller).to receive(:selection_bucket).and_return(selection) }
    
    it "moves resources and indexes everything" do
      expect(Trifle::IIIFManifest.all_in_collection(collection1).map(&:id)).to match_array([manifest1.id,manifest2.id])
      expect(Trifle::IIIFManifest.all_in_collection(collection3).map(&:id)).to match_array([manifest3.id,manifest4.id])
      expect(collection3.ordered_members.to_a.map(&:id)).to match_array([manifest3.id,manifest4.id])
      expect_publish_for = { # These should have PublishJobs queued for them
        collection2.id => false,
        manifest1.id => false,
        manifest2.id => false,
        collection4.id => false
      }
      expect_update_for = { 
        # These should have UpdateIndexJobs queued for them.
        # Note that manifests do update_index directly, only collections are done in a job.
        collection4.id => false
      }
      allow_any_instance_of(Trifle::PublishJob).to receive(:queue_job) do |job|
        expect(expect_publish_for.key?(job.resource.id)).to eql(true)
        expect_publish_for[job.resource.id] = true
      end
      allow_any_instance_of(Trifle::UpdateIndexJob).to receive(:queue_job) do |job|
        expect(expect_update_for.key?(job.resource.id)).to eql(true)
        expect_update_for[job.resource.id] = true
      end
      
      post :move_selection_into, id: collection3.id
      
      expect(expect_publish_for.values).to all( eql(true) )
      expect(expect_update_for.values).to all( eql(true) )
      expect(bucket).to be_empty
      
      collection2_reloaded = Trifle::IIIFCollection.find(collection2.id)
      expect(collection2_reloaded.ordered_members.to_a).to be_empty

      collection3_reloaded = Trifle::IIIFCollection.find(collection3.id)
      expect(collection3_reloaded.ordered_members.to_a.map(&:id)).to match_array([manifest1.id,manifest2.id,manifest3.id,manifest4.id,collection4.id])
      
      expect(Trifle::IIIFManifest.all_in_collection(collection1).map(&:id)).to eql([])
      expect(Trifle::IIIFManifest.all_in_collection(collection3).map(&:id)).to match_array([manifest1.id,manifest2.id,manifest3.id,manifest4.id])
    end
  end
  
  describe "iiif publishing" do
    before { allow(Trifle::IIIFCollection).to receive(:ark_naan).and_return('12345') }
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    let(:collection) { collection2.parent }
    let(:collection2) { FactoryGirl.create(:iiifcollection, :with_parent) }
    let(:collection3) { FactoryGirl.create(:iiifcollection) }
    let(:collection4) { FactoryGirl.create(:iiifcollection) }
    it "publishes after create" do
      expect(Trifle.queue).to receive(:push).with(kind_of(Trifle::PublishJob)) do |job|
        expect(job.resource.title).to eql('created collection')
        expect(job.resource_id).to be_present
      end
      post :create, iiif_collection_id: collection.id, iiif_collection: { title: 'created collection' }
    end
    it "publishes after update" do
      expect(Trifle.queue).to receive(:push).with(kind_of(Trifle::PublishJob)) do |job|
        expect(job.resource_id).to eql(collection.id)
      end
      post :update, id: collection.id, iiif_collection: { title: 'new title' }
    end
    it "removes published iiif after destroy" do
      collection ; collection2 # create by reference
      expect(Trifle.queue).to receive(:push).with(kind_of(Trifle::PublishJob)) do |job|
        expect(job.resource_id).to eql(collection.id)
        expect(job.remove_id).to eql(collection2.id)
        expect(job.remove_type).to eql('collection')
      end
      delete :destroy, id: collection2.id
    end
    it "removes published iiif after destroying top level collection" do
      collection3 ; collection4 # create by reference
      expect(Trifle::IIIFCollection.count).to eql(2)
      expect(Trifle.queue).to receive(:push).with(kind_of(Trifle::PublishJob)) do |job|
        expect(job.resource_id).to eql(collection3.id)
        expect(job.remove_id).to eql(collection4.id)
        expect(job.remove_type).to eql('collection')
      end
      delete :destroy, id: collection4.id
    end
  end

  context "with anonymous user" do
    describe "GET #show_iiif" do
      let(:collection) { FactoryGirl.create(:iiifcollection, :with_manifests) }
      it "renders manifest json" do
        expect_any_instance_of(Trifle::IIIFCollection).to receive(:to_iiif).and_call_original
        get :show_iiif, id: collection.id
        expect(JSON.parse(response.body)).to be_a(Hash)
        expect(response.body).to include(collection.manifests.first.title)
      end
    end
    
    describe "GET #show_iiif for mirador" do
      let(:manifest) { FactoryGirl.create(:iiifmanifest) }
      let!(:collection) { FactoryGirl.create(:iiifcollection, keeper: 'Test Keeper', ordered_members: [manifest]) }
      before { Trifle::IIIFManifest.all.each do |c| c.update_index end }
      let(:json) { JSON.parse(response.body) }
      describe "using manifestUri" do
        it "renders json" do
          get :show_iiif, id: collection.id, mirador: 'true'
          expect(json).to be_a(Array)
          expect(json[0]['manifestUri']).to be_present
          expect(response.body).to include(manifest.id)
          expect(response.body).to include('"location":"Test Keeper"')
        end
      end
      describe "using collectionContent" do
        it "renders json" do
          get :show_iiif, id: collection.id, mirador: 'collection'
          expect(json).to be_a(Array)
          expect(json[0]['collectionContent']['@type']).to eql('sc:Collection')
          expect(json[0]['collectionContent']['label']).to eql(collection.title)
        end
      end
    end    
  end
  
  describe "GET #show full lists" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    
    let!(:sub_collection) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest3]) }
    let!(:other_collection) { FactoryGirl.create(:iiifcollection, ordered_members: [manifest4]) }
    before {
      collection.ordered_members = [sub_collection, manifest1, manifest2]
      collection.save
      Trifle::IIIFManifest.all.each do |m| m.update_index end
      sub_collection.update_index
    }
    let(:manifest1) { FactoryGirl.build(:iiifmanifest)}
    let(:manifest2) { FactoryGirl.build(:iiifmanifest)}
    let(:manifest3) { FactoryGirl.build(:iiifmanifest)}
    let(:manifest4) { FactoryGirl.build(:iiifmanifest)}
    let(:json) { JSON.parse(response.body) }
    
    it "sends full manifest list" do
      expect(Trifle::IIIFManifest).to receive(:all_in_collection).and_call_original
      get :show, id: collection.id, full_manifest_list: '1'
      expect(json).to be_a(Hash)
      expect(json['resources']).to be_a(Array)
      expect(json['resources'].count).to eql(3)
      expect(json['resources'].map do |m| m['id'] end).to match_array([manifest1.id,manifest2.id,manifest3.id])
    end
    
    it "sends full collection list" do
      expect(Trifle::IIIFCollection).to receive(:all_in_collection).and_call_original
      get :show, id: collection.id, full_collection_list: '1'
      expect(json).to be_a(Hash)
      expect(json['resources']).to be_a(Array)
      expect(json['resources'].count).to eql(1)
      expect(json['resources'].map do |m| m['id'] end).to match_array([sub_collection.id])
    end
  end
  
  
  describe "GET #index_iiif" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    let(:json) { JSON.parse(response.body) }
    let!(:collection) { FactoryGirl.create(:iiifcollection) }
    let!(:collection2) { FactoryGirl.create(:iiifcollection) }
    it "returns top collections" do
      expect(Trifle::IIIFCollection).to receive(:index_collection_iiif).and_call_original
      get :index_iiif
      expect(json['collections'].count).to eql(2)
      expect(json['@id']).to be_present
    end
  end
  
  
  describe "#set_new_resource" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before {
      allow(Trifle).to receive(:config).and_return({'ark_naan' => '11111', 'allowed_ark_naan' => ['11111','22222','33333']})
      collection.identifier = ['ark:/22222/collection']
      collection.save
      sign_in user
    }
    it "sets parent naan" do
      post :create, iiif_collection_id: collection.id, iiif_collection: { title: 'created manifest' }      
      expect(assigns(:resource).local_ark_naan).to eql('22222')
    end
    it "allows overriding naan" do
      post :create, iiif_collection_id: collection.id, iiif_collection: { title: 'created manifest', ark_naan: '33333' }
      expect(assigns(:resource).local_ark_naan).to eql('33333')
    end    
  end
  
end