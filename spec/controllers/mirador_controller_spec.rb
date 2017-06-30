require 'rails_helper'

RSpec.describe Trifle::MiradorController, type: :controller do

  routes { Trifle::Engine.routes }
  
  let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_parent, :with_images) }

  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }
    it "renders" do
      expect(controller).to receive(:show).and_call_original
      get :show, id: manifest.to_param, page: 1
      expect(assigns[:manifest]).to be_a(Trifle::IIIFManifest)
      expect(assigns[:collection]).to be_a(Trifle::IIIFCollection)
      expect(assigns[:image]).to be_a(Trifle::IIIFImage)
    end
  end

  context "with anonymous user" do
    describe "POST export_images" do
      it "denies access" do
        expect(controller).not_to receive(:show)
        get :show, id: manifest.to_param
      end
    end
  end

end