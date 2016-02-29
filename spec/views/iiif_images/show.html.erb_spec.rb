require 'rails_helper'

RSpec.describe "trifle/iiif_images/show", type: :view do
  let( :image ) { FactoryGirl.create(:iiifimage, :with_manifest) }
  before do
    assign(:resource, image)
    assign(:presenter, Trifle::IIIFImagesController.presenter_class.new(image))
    controller.request.path_parameters[:id] = image.id
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
  end
end
