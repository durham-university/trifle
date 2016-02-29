require 'rails_helper'

RSpec.describe "trifle/iiif_collections/edit", type: :view do
  let( :collection ) { FactoryGirl.create(:iiifcollection, :with_parent, :with_manifests) }
  before do
    assign(:resource, collection)
    assign(:form, Trifle::IIIFCollectionsController.edit_form_class.new(collection))
    controller.request.path_parameters[:id] = collection.id
  end

  helper( Trifle::ApplicationHelper )
  
  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
    assert_select "form[action=?][method=?]", trifle.iiif_collection_path(collection), "post" do
    end
  end
end
