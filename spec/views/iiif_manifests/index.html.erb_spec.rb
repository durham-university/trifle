require 'rails_helper'

RSpec.describe "trifle/iiif_manifests/index", type: :view do
  let!( :manifest ) { FactoryGirl.create(:iiifmanifest, :with_parent) }
  let!( :manifest2 ) { FactoryGirl.create(:iiifmanifest, :with_parent) }
  before do
    assign(:resources,Trifle::IIIFManifestsController.resources_for_page(1))
  end

  helper( Trifle::ApplicationHelper )

  let(:page) { Capybara::Node::Simple.new(rendered) }

  let(:user) { FactoryGirl.create(:user,:admin) }
  before { sign_in user }

  it "renders a list of resources" do
    render
    expect(page).to have_selector("a[href='#{trifle.iiif_manifest_path(manifest)}']")
    expect(page).to have_selector("a[href='#{trifle.iiif_manifest_path(manifest2)}']")
  end
end
