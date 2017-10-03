require 'rails_helper'

RSpec.describe Trifle::BackgroundJobContainersController, type: :controller do

  routes { Trifle::Engine.routes }

  context "with admin user" do
    let(:user) { FactoryGirl.create(:user, :admin) }
    before { sign_in user }

    describe "POST #start_publish_all_job" do
      it "starts the job" do
        expect(Trifle.queue).to receive(:push).with(Trifle::PublishAllJob)
        post :start_publish_all_job
      end
    end
  end
  
  context "with anonymous user" do
    describe "POST #start_publish_all_job" do
      it "doesn't start the job" do
        expect(Trifle.queue).not_to receive(:push)
        post :start_publish_all_job
      end
    end
  end
  
  context "with registered user" do
    let(:user) { FactoryGirl.create(:user) }
    before { sign_in user }
    
    describe "POST #start_publish_all_job" do
      it "doesn't start the job" do
        expect(Trifle.queue).not_to receive(:push)
        post :start_publish_all_job
      end
    end
  end
end
