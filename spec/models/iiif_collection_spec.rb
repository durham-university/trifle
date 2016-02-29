require 'rails_helper'

RSpec.describe Trifle::IIIFCollection do
  let(:collection) { FactoryGirl.build(:iiifcollection) }
  
  describe "#iiif_collection" do
    let(:collection) { FactoryGirl.create(:iiifcollection,:with_manifests) }
    it "makes a valid iiif_collection object" do
      c = collection.iiif_collection
      expect(c).to be_a(IIIF::Presentation::Collection)
      json = c.to_json
      expect(json).to be_a(String)
      expect(json).to include(collection.manifests.first.title)
    end
  end

  describe "#to_iiif" do
    it "calls #iiif_collection" do
      expect(collection).to receive(:iiif_collection).and_return({test: 'foo'})
      expect(collection.to_iiif).to eql({test:"foo"})
    end
  end  
  
  describe "#as_json" do
    let(:collection) { FactoryGirl.build(:iiifcollection)}
    let(:json) { collection.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
    end
    context "with parent" do
      let(:collection) { FactoryGirl.create(:iiifcollection, :with_parent)}
      it "sets parent_id" do
        expect(json['parent_id']).to be_present
      end
    end
    context "with include_children" do
      let(:collection) { FactoryGirl.build(:iiifcollection, :with_manifests )}
      let(:json) { collection.as_json(include_children: true) }
      it "includes child objects" do
        expect(json['manifests'].length).to be > 0
      end
    end
  end
  
  describe "#to_solr" do
    let(:solr_doc) { collection.to_solr }
    context "with a parent" do
      let(:collection) { FactoryGirl.create(:iiifcollection, :with_parent)}
      it "includes root collection id in solr" do
        expect(solr_doc[Solrizer.solr_name('root_collection_id', type: :symbol)]).to eql(collection.root_collection.id)
      end
    end
    context "with a root object" do
      it "doesn't add solr field" do
        expect(solr_doc.key?(Solrizer.solr_name('root_collection_id', type: :symbol))).to eql(false)
      end
    end
  end
  
  describe "::all_in_collections" do
    let!(:root1) { FactoryGirl.create(:iiifcollection, ordered_members: [col1, col2]) }
    let!(:root2) { FactoryGirl.create(:iiifcollection, ordered_members: [col3]) }
    let(:col1) { FactoryGirl.create(:iiifcollection) }
    let(:col2) { FactoryGirl.create(:iiifcollection) }
    let(:col3) { FactoryGirl.create(:iiifcollection) }
    before { [col1, col2, col3].each do |c| c.update_index end }
    let(:all) { Trifle::IIIFCollection.all_in_collection(root1) }
    it "returns all in specified collection" do
      expect(all.count).to eql(2)
      expect(all.map(&:id)).to match_array([col1.id,col2.id])
    end
  end
end
