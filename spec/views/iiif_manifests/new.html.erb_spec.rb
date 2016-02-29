require 'rails_helper'

RSpec.describe "trifle/iiif_manifests/new", type: :view do
  let( :manifest ) { FactoryGirl.create(:iiifmanifest, :with_parent, :with_images) }
  before do
    assign(:resource, manifest)
    assign(:form, Trifle::IIIFManifestsController.edit_form_class.new(manifest))
    controller.request.path_parameters[:id] = manifest.id
  end

  helper( Trifle::ApplicationHelper )
  
  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
    assert_select "form[action=?][method=?]", trifle.iiif_manifest_path(manifest), "post" do
    end
  end
end
