require 'rails_helper'

RSpec.describe "trifle/iiif_manifests/show", type: :view do
  let( :manifest ) { FactoryGirl.create(:iiifmanifest, :with_parent, :with_images) }
  before do
    assign(:resource, manifest)
    assign(:presenter, Trifle::IIIFManifestsController.presenter_class.new(manifest))
    controller.request.path_parameters[:id] = manifest.id
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
  end
end
