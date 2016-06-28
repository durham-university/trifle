require 'rails_helper'

RSpec.describe Trifle::IIIFCollectionsController, type: :controller do

  let(:collection) { FactoryGirl.create(:iiifcollection) }

  routes { Trifle::Engine.routes }
  
  
  before {
    allow(Trifle.queue).to receive(:push).and_return(true)
  }
  
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
    
    describe "GET #show_iiif?mirador=true" do
      let(:manifest) { FactoryGirl.create(:iiifmanifest) }
      let!(:collection) { FactoryGirl.create(:iiifcollection, ordered_members: [FactoryGirl.create(:iiifcollection, ordered_members: [manifest])]) }
      before { Trifle::IIIFManifest.all.each do |c| c.update_index end }
      it "renders manifest json" do
        get :show_iiif, id: collection.id, mirador: 'true'
        expect(JSON.parse(response.body)).to be_a(Array)
        expect(response.body).to include(manifest.id)
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
  end
  
end