require 'rails_helper'

RSpec.describe Trifle::IIIFCollectionsController, type: :controller do

  let(:collection) { FactoryGirl.create(:iiifcollection) }

  routes { Trifle::Engine.routes }
  
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
  end
  
end