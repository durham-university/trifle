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
    it "adds digitisation note" do
      collection.description = 'description'
      collection.digitisation_note = 'digitisation_note'
      c = collection.iiif_collection
      json = c.to_json
      expect(json).to include("\"description\\ndigitisation_note\"")      
    end    
  end
  
  describe "::index_collection_iiif" do
    let!(:collection) { FactoryGirl.create(:iiifcollection,:with_sub_collections) }
    let!(:collection2) { FactoryGirl.create(:iiifcollection,:with_sub_collections) }
    let(:iiif) { Trifle::IIIFCollection.index_collection_iiif }
    before { allow(Trifle).to receive(:config).and_return({ark_naan: '12345', index_collection: {'label' => 'test label', logo: 'http://www.example.com/logo.jpg'}})}
    it "creates index collection iiif" do
      expect(Trifle::IIIFCollection.count).to be > 2
      expect(iiif['label']).to eql('test label')
      expect(iiif['@id']).to be_present
      expect(iiif['collections'].count).to eql(2)
      expect(iiif['collections'].map do |c| c['label'] end).to match_array ([collection.title, collection2.title])
      expect(iiif['logo']).to eql('http://www.example.com/logo.jpg')
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
  
  describe "id minting" do
    before { File.unlink('/tmp/test-minter-state_collection') if File.exists?('/tmp/test-minter-state_collection') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:id) { collection.assign_id }
    it "uses collection minter" do
      expect(id).to start_with('t0c')
    end
  end  
  
  describe "#inherited_logo" do
    let(:logo1) { 'http://www.example.com/logo1.png' }
    let(:logo2) { 'http://www.example.com/logo2.png' }
    let(:logo3) { 'http://www.example.com/logo3.png' }
    let(:collection) { FactoryGirl.create(:iiifcollection) }
    let(:parent) {
      FactoryGirl.create(:iiifcollection, logo: logo2).tap do |c| 
        c.ordered_members << collection
        c.save
      end
    }
    let(:gparent) {
      FactoryGirl.create(:iiifcollection, logo: logo3).tap do |c| 
        c.ordered_members << parent
        c.save
      end
    }
    it "returns logo in self" do
      collection.logo = logo1
      expect(collection.inherited_logo).to eql(logo1)
    end
    it "returns logo from parent" do
      parent # create by reference
      expect(collection.inherited_logo).to eql(logo2)      
    end
    it "returns logo from grand parent" do
      gparent # create by reference
      parent.logo = nil
      parent.save
      expect(collection.inherited_logo).to eql(logo3)
    end
    it "returns nil if no parent" do
      expect(collection.inherited_logo).to be_nil
    end
  end
  
  describe "source record" do
    # iiif_manifest_spec has more source record tests, manifest and collection share the same concern
    let(:manifest) { FactoryGirl.build(:iiifcollection, source_record: 'schmit:ark:/12345/testid#subid') }    
    describe "#source_type" do
      it "returns the source type" do
        expect(manifest.source_type).to eql('schmit')
      end
    end
    describe "#source_url" do
      it "retuns a schmit link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_base_url' => 'http://www.example.com/schmit'})
        collection.source_record = 'schmit:ark:/12345/test1234'
        expect(collection.source_url).to eql('http://www.example.com/schmit/catalogues/test1234')
      end
    end
    describe "#public_source_link" do
      it "returns a iiif link to xtf" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        collection.source_record = 'schmit:ark:/12345/test'
        link = collection.public_source_link
        expect(link['@id']).to eql('http://www.example.com/xtf/view?docId=12345_test.xml')
        expect(link['label']).to be_present
      end
      it "returns nil if no link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        collection.source_record = nil
        expect(collection.public_source_link).to be_nil
      end
    end
    describe "::find_from_source" do
      let!(:collection1) { FactoryGirl.create(:iiifcollection, source_record: 'schmit:ark:/12345/testid1#subid\\1') }    
      let!(:collection2) { FactoryGirl.create(:iiifcollection, source_record: 'schmit:ark:/12345/testid1#subid\\2') }    
      let!(:collection3) { FactoryGirl.create(:iiifcollection, source_record: 'schmit:ark:/12345/testid2#subid"1"') }    
      
      context "prefix search" do
        let(:result1) { Trifle::IIIFCollection.find_from_source('schmit:ark:/12345/testid1#')}
        let(:result2) { Trifle::IIIFCollection.find_from_source('schmit:ark:/12345/testid2#')}
        let(:result3) { Trifle::IIIFCollection.find_from_source('schmit:ark:/12345/testid\\2')}
        it "finds correct manifests" do
          expect(result1.map(&:id)).to match_array([collection1.id,collection2.id])
          expect(result2.map(&:id)).to match_array([collection3.id])
          expect(result3.empty?).to eql(true)
        end
      end
    end
  end

  describe "#to_millennium" do
    # iiif_manifest_spec has some more millennium linking related tests
    before { allow(Trifle::IIIFCollection).to receive(:ark_naan).and_return('12345') }
    let(:collection) { FactoryGirl.create(:iiifcollection) } # need ark and id in collection
    it "returns nil when source is not in millennium" do
      collection.source_record = nil
      expect(collection.to_millennium).to be_nil
      collection.source_record = "schmit:test"
      expect(collection.to_millennium).to be_nil
    end
    it "returns millennium records" do
      collection.source_record = "millennium:12345#test"
      mil = collection.to_millennium
      expect(mil['12345'][0].to_s).to eql("533    $8 1\\u $a Digital image $5 UkDhU ")
      expect(mil['12345'][1].to_s).to eql("856 41 $8 1\\u $z Online version $u https://n2t.durham.ac.uk/ark:/12345/#{collection.id}.html ")
      collection.digitisation_note = 'test digitisation note'
      mil = collection.to_millennium
      expect(mil['12345'][0].to_s).to eql("533    $8 1\\u $a Digital image $n test digitisation note $5 UkDhU ")
    end
  end
  
end
