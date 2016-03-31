require 'rails_helper'

RSpec.describe "trifle/iiif_images/new", type: :view do
  let( :structure ) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure) }
  before do
    assign(:resource, structure)
    assign(:form, Trifle::IIIFStructuresController.edit_form_class.new(structure))
    controller.request.path_parameters[:id] = structure.id
  end
  helper( Trifle::ApplicationHelper )
  
  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
    assert_select "form[action=?][method=?]", trifle.iiif_structure_path(structure), "post" do
    end
  end
end
