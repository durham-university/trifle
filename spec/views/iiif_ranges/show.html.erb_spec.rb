require 'rails_helper'

RSpec.describe "trifle/iiif_ranges/show", type: :view do
  let( :range ) { FactoryGirl.create(:iiifrange, :with_manifest, :with_canvases, :with_sub_range) }
  before do
    assign(:resource, range)
    assign(:presenter, Trifle::IIIFRangesController.presenter_class.new(range))
    controller.request.path_parameters[:id] = range.id
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
  end
end
