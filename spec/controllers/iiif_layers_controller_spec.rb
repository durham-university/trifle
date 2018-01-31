require 'rails_helper'

RSpec.describe Trifle::IIIFLayersController, type: :controller do

  routes { Trifle::Engine.routes }

  let(:image) { FactoryGirl.create(:iiifimage, :with_manifest, :with_layers)}
  let(:manifest) { image.manifest }
  let(:layer) { image.layers[0] }

  context "with anonymous user" do
    describe "POST #create" do
      it "fails authentication" do
        expect {
          post :create, iiif_manifest_id: manifest.id, iiif_image_id: image.id, iiif_layer: { title: 'test layer', width: '100', height: '100' }
        } .not_to change {
          image.reload
          image.layers.count
        }
      end
    end

    describe "POST #convert_to_image" do
      it "fails authentication" do
        expect(Trifle::LayersActor).not_to receive(:new)
        expect {
          post :convert_to_image, iiif_manifest_id: manifest.id, id: layer.id
        } .not_to change {
          image.reload
          image.layers.count
        }
      end
    end
  end

  context "with admin user" do
    let(:user) { FactoryGirl.create(:user,:admin) }
    before { sign_in user }

    describe "POST #create" do
      it "adds new layer to image" do
        expect {
          post :create, iiif_manifest_id: manifest.id, iiif_image_id: image.id, iiif_layer: { title: 'test layer', width: '100', height: '100' }
        } .to change {
          image.reload
          image.layers.count
        } .by(1)
      end
    end

    describe "POST #convert_to_image" do
      it "convert the layer to an image" do
        expect_any_instance_of(Trifle::LayersActor).to receive(:make_layer_an_image).and_call_original
        expect {
          post :convert_to_image, iiif_manifest_id: manifest.id, id: layer.id
        } .to change {
          image.reload
          image.layers.count
        } .by(-1) .and change {
          manifest.reload
          manifest.images.count
        } .by(1)
      end
    end      
    
  end

end