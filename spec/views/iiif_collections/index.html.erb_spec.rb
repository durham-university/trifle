require 'rails_helper'

RSpec.describe "trifle/iiif_collections/index", type: :view do
  let!( :collection ) { FactoryGirl.create(:iiifcollection) }
  let!( :collection2 ) { FactoryGirl.create(:iiifcollection, ordered_members: [collection3]) }
  let!( :collection3 ) { FactoryGirl.create(:iiifcollection) }
  before do
    assign(:resources, Trifle::IIIFCollection.root_collections)
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders a list of resources" do
    render
    expect(page).to have_selector("a[href='#{trifle.iiif_collection_path(collection)}']")
    expect(page).to have_selector("a[href='#{trifle.iiif_collection_path(collection2)}']")
    expect(page).not_to have_selector("a[href='#{trifle.iiif_collection_path(collection3)}']")
  end
end
