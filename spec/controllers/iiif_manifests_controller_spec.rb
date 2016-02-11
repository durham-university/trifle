require 'rails_helper'

RSpec.describe Trifle::IIIFManifestsController, type: :controller do

  let(:manifest) { FactoryGirl.create(:iiifmanifest) }

  routes { Trifle::Engine.routes }
  
  context "with anonymous user" do
    before {
      expect_any_instance_of(Trifle::DepositJob).not_to receive(:queue_job)
    }
    describe "POST #deposit_images" do
      it "fails authentication" do
        post :deposit_images, id: manifest.id
        # not receive queue_job in before block
      end
    end
    
    describe "POST #create_and_deposit_images" do
      it "fails authentication" do
        expect {
          post :create_and_deposit_images
        }.not_to change(Trifle::IIIFManifest, :count)
      end
    end
  end
  
  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    let(:deposit_items) { ['http://localhost/dummy1', 'http://localhost/dummy2'] }
    
    describe "POST #deposit_images" do
      it "queues a job with deposit items" do
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job) { |job|
            expect(job.deposit_items).to eql(deposit_items)
            expect(job.resource.id).to eql(manifest.id)
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
        expect {
          post :create_and_deposit_images, deposit_items: deposit_items
        }.to change(Trifle::IIIFManifest, :count).by(1)
      end
      it "returns json" do
        expect_any_instance_of(Trifle::DepositJob).to receive(:queue_job).and_return(true)        
        post :create_and_deposit_images, deposit_items: deposit_items, format: 'json'
        parsed = JSON.parse(response.body)
        expect(parsed['resource']['id']).to be_present
        expect(parsed['status']).to eql('ok')
      end
    end
    
  end
  

end