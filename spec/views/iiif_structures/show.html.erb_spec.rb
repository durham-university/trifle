require 'rails_helper'

RSpec.describe "trifle/iiif_structures/show", type: :view do
  let( :structure ) { FactoryGirl.create(:iiifstructure, :with_manifest, :with_canvases, :with_sub_structure) }
  before do
    assign(:resource, structure)
    assign(:presenter, Trifle::IIIFStructuresController.presenter_class.new(structure))
    controller.request.path_parameters[:id] = structure.id
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
  end
end
