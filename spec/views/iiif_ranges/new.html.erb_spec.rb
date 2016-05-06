require 'rails_helper'

RSpec.describe "trifle/iiif_ranges/new", type: :view do
  let( :range ) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range) }
  before do
    assign(:resource, range)
    assign(:form, Trifle::IIIFRangesController.edit_form_class.new(range))
    controller.request.path_parameters[:id] = range.id
  end
  helper( Trifle::ApplicationHelper )
  
  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
    assert_select "form[action=?][method=?]", trifle.iiif_range_path(range), "post" do
    end
  end
end
