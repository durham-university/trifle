require 'rails_helper'

RSpec.describe "trifle/iiif_images/edit", type: :view do
  let( :image ) { FactoryGirl.create(:iiifimage, :with_manifest) }
  before do
    assign(:resource, image)
    assign(:form, Trifle::IIIFImagesController.edit_form_class.new(image))
    controller.request.path_parameters[:id] = image.id
  end

  helper( Trifle::ApplicationHelper )
  
  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
    assert_select "form[action=?][method=?]", trifle.iiif_image_path(image), "post" do
    end
  end
end
