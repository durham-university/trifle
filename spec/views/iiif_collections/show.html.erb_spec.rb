require 'rails_helper'

RSpec.describe "trifle/iiif_collections/show", type: :view do
  let( :collection ) { FactoryGirl.create(:iiifcollection, :with_parent, :with_manifests) }
  before do
    assign(:resource, collection)
    assign(:presenter, Trifle::IIIFCollectionsController.presenter_class.new(collection))
    controller.request.path_parameters[:id] = collection.id
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders attributes in" do
    render
  end

  it "doesn't render inherited source records" do
    allow(collection).to receive(:public_source_link).and_return({'@id' => 'http://www.example.com/sourcerecord', 'label' => 'test'})
    expect(collection.source_record).to be_nil
    render
    expect(rendered).not_to include('http://www.example.com/sourcerecord')
  end
end
