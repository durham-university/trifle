require 'rails_helper'

RSpec.describe Trifle::IIIFManifest do
  let(:manifest) { FactoryGirl.build(:iiifmanifest) }
  describe "#add_deposited_image" do
    let(:image) { FactoryGirl.build(:iiifimage, title: 'dummy image') }
    it "adds the image to ordered_members" do
      manifest.add_deposited_image(image)
      expect(manifest.reload.ordered_members.to_a.map(&:title)).to eql(['dummy image'])
    end
  end
  
  describe "#parent_id" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_parent) }
    it "returns the id of parent" do
      expect(manifest.instance_variable_get(:@one_parent)).to be_nil
      expect(manifest.parent_id).to be_present
    end
    it "uses @one_parent when set" do
      manifest.has_parent!(double('dummy parent',id: 'testparentid'))
      expect(manifest.parent_id).to eql('testparentid')
    end
  end
  
  describe "#default_container_location!" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest, image_container_location: nil) }
    it "doesn't do anything if already set" do
      manifest.image_container_location = 'dummy'
      manifest.default_container_location!
      expect(manifest.image_container_location).to eql('dummy')
    end
    
    context "with a persisted manifest and no ark" do
      before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
      before { manifest.save }
      it "sets the container_location to be the same as id" do
        manifest.default_container_location!
        expect(manifest.image_container_location).to eql("12345/#{manifest.id[0..1]}/#{manifest.id[2..3]}/#{manifest.id[4..5]}/#{manifest.id}")
      end
    end
    context "with a new manifest" do
      before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
      it "it reserves an ark and sets that as container_location" do
        manifest.default_container_location!
        manifest.save
        expect(manifest.image_container_location).to eql("12345/#{manifest.id[0..1]}/#{manifest.id[2..3]}/#{manifest.id[4..5]}/#{manifest.id}")
      end
    end
  end
  
  describe "#iiif_manifest" do
    let(:manifest) { FactoryGirl.create(:iiifmanifest,:with_images,:with_range) }
    it "makes a valid iiif_manifest object" do
      manifest.description = 'test description'
      allow(manifest).to receive(:inherited_logo).and_return('http://www.example.com/logo.png')
      m = manifest.iiif_manifest
      expect(m).to be_a(IIIF::Presentation::Manifest)
      json = m.to_json
      expect(json).to be_a(String)
      expect(json).to include(manifest.images.first.image_location)
      expect(json).to include(manifest.ranges.first.id)
      expect(json).to include("\"#{manifest.title}\"")
      expect(json).to include("\"test description\"")
      expect(json).to include('http://www.example.com/logo.png')
    end
    it "adds digitisation note" do
      manifest.description = 'description'
      manifest.digitisation_note = 'digitisation_note'
      m = manifest.iiif_manifest
      json = m.to_json
      expect(json).to include("\"description\\ndigitisation_note\"")      
    end
    it "includes source link" do
      allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
      manifest.source_record = 'schmit:ark:/12345/test'
      json = manifest.iiif_manifest
      expect(json['related']['@id']).to eql('http://www.example.com/xtf/view?docId=12345_test.xml')
      expect(json['related']['label']).to be_present
      
      manifest.source_record = 'schmit:ark:/12345/test#fragment'
      json = manifest.iiif_manifest
      expect(json['related']['@id']).to eql('http://www.example.com/xtf/view?docId=12345_test.xml#fragment')
    end
  end
  
  describe "#to_iiif" do
    it "calls #iiif_manifest" do
      expect(manifest).to receive(:iiif_manifest).and_return({test: 'foo'})
      expect(manifest.to_iiif).to eql({test: 'foo'})
    end
  end
  
  describe "#as_json" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest)}
    let(:json) { manifest.as_json }
    it "sets properties" do
      expect(json['title']).to be_present
      expect(json['serialised_ranges']).to be_nil
    end
    context "with parent" do
      let(:manifest) { FactoryGirl.create(:iiifmanifest, :with_parent)}
      it "sets parent_id" do
        expect(json['parent_id']).to be_present
      end
    end
    context "with include_children" do
      let(:manifest) { FactoryGirl.build(:iiifmanifest, :with_images )}
      let(:json) { manifest.as_json(include_children: true) }
      it "includes child objects" do
        expect(json['images'].length).to be > 0
      end
    end
  end  
  
  describe "#to_solr" do
    let(:solr_doc) { manifest.to_solr }
    context "with a parent" do
      let(:manifest) { FactoryGirl.create(:iiifcollection, :with_parent)}
      it "includes root collection id in solr" do
        expect(solr_doc[Solrizer.solr_name('root_collection_id', type: :symbol)]).to eql(manifest.root_collection.id)
      end
    end
    context "with a root object" do
      it "doesn't add solr field" do
        expect(solr_doc.key?(Solrizer.solr_name('root_collection_id', type: :symbol))).to eql(false)
      end
    end
    context "with ranges" do 
      let(:manifest) { FactoryGirl.create(:iiifmanifest) }
      let(:range) { FactoryGirl.build(:iiifrange, manifest: manifest) }
      before {
        manifest.ranges.push(range)
        range.save
      }
      it "adds ranges to object profile" do
        profile = JSON.parse(solr_doc['object_profile_ssm'])
        expect(profile['serialised_ranges']).to be_present
      end
    end
  end  
  
  describe "#ranges" do
    let(:test_string) { "\xE2\x80\x9C\xC3\xA4".force_encoding("UTF-8") }    
    let(:manifest) { FactoryGirl.create(:iiifmanifest) }
    let(:range) { FactoryGirl.build(:iiifrange, manifest: manifest, title: test_string) }
    let(:range2) { FactoryGirl.build(:iiifrange, manifest: manifest) }
    it "saves and loads ranges" do
      expect(manifest.ranges.count).to eql(0)
      manifest.ranges.push(range)
      range.save
      
      reloaded = Trifle::IIIFManifest.find(manifest.id)
      expect(reloaded.ranges.count).to eql(1)
      
      manifest.ranges.push(range2)
      range2.save
      
      reloaded = Trifle::IIIFManifest.find(manifest.id)
      expect(reloaded.ranges.count).to eql(2)      
      expect(reloaded.ranges[0].id).to eql(range.id)
      expect(reloaded.ranges[0].title).to eql(range.title)
      expect(reloaded.ranges[1].id).to eql(range2.id)
      expect(reloaded.ranges[1].title).to eql(range2.title)
      
      reloaded = Trifle::IIIFManifest.load_instance_from_solr(manifest.id)
      expect(reloaded.ranges.count).to eql(2)      
      expect(reloaded.ranges[0].id).to eql(range.id)
      expect(reloaded.ranges[0].title).to eql(range.title)
      expect(reloaded.ranges[1].id).to eql(range2.id)
      expect(reloaded.ranges[1].title).to eql(range2.title)
    end
  end
  
  describe "source record" do
    let(:manifest) { FactoryGirl.build(:iiifmanifest, source_record: 'schmit:ark:/12345/testid#subid') }    
    describe "#source_type" do
      it "returns the source type" do
        expect(manifest.source_type).to eql('schmit')
      end
    end
    describe "#source_url" do
      it "retuns a schmit link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_base_url' => 'http://www.example.com/schmit'})
        manifest.source_record = 'schmit:ark:/12345/test1234'
        expect(manifest.source_url).to eql('http://www.example.com/schmit/catalogues/test1234')
      end
    end
    describe "#public_source_link" do
      it "returns a iiif link to xtf" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        manifest.source_record = 'schmit:ark:/12345/test'
        link = manifest.public_source_link
        expect(link['@id']).to eql('http://www.example.com/xtf/view?docId=12345_test.xml')
        expect(link['label']).to be_present
      end
      it "returns parent link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        collection = FactoryGirl.create(:iiifcollection, source_record: 'schmit:ark:/12345/parenttest')
        collection.ordered_members << manifest
        collection.save
        manifest.source_record = nil
        link = manifest.public_source_link
        expect(link['@id']).to eql('http://www.example.com/xtf/view?docId=12345_parenttest.xml')
        expect(link['label']).to be_present
      end
      it "returns nil if no link" do
        allow(Schmit::API).to receive(:config).and_return({'schmit_xtf_base_url' => 'http://www.example.com/xtf/view?docId='})
        collection = FactoryGirl.create(:iiifcollection)
        collection.ordered_members << manifest
        collection.save
        manifest.source_record = nil
        expect(manifest.public_source_link).to be_nil
      end
    end
    describe "#source_identifier" do
      it "returns source identifier" do
        expect(manifest.source_identifier).to eql('ark:/12345/testid#subid')
      end
    end
    describe "#refresh_from_source" do
      it "calls schmit version" do
        expect(manifest).to receive('refresh_from_schmit_source')
        manifest.refresh_from_source
      end
      it "calls millenium version" do 
        manifest.source_record='millenium:test'
        expect(manifest).to receive('refresh_from_millenium_source')
        manifest.refresh_from_source        
      end
    end
    describe "#refresh_from_schmit_source" do
      let(:manifest_api) { 
        double('manifest_api_mock').tap do |mock|
          expect(mock).to receive(:xml_record).and_return(double('xml_record_mock').tap do |mock|
            expect(mock).to receive(:sub_item).with('subid').and_return(double('sub_record_mock').tap do |mock|
              allow(mock).to receive(:title_path).and_return('catalogue of new title')
              allow(mock).to receive(:title).and_return('catalogue of new title')
              allow(mock).to receive(:date).and_return('new date')
              allow(mock).to receive(:scopecontent).and_return('new scopecontent')
            end)
          end)
        end
      }
      
      it "fetches new information from source" do
        expect(Schmit::API::Catalogue).to receive(:try_find).with('ark:/12345/testid').and_return(manifest_api)
        manifest.refresh_from_schmit_source
        # Title should not be overwritten
        expect(manifest.title).not_to include('new title')
        expect(manifest.date_published).to eql('new date')
        expect(manifest.description).to eql('new scopecontent')
      end
    end
    describe "::find_from_source" do
      let!(:manifest1) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid1#subid\\1') }    
      let!(:manifest2) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid1#subid\\2') }    
      let!(:manifest3) { FactoryGirl.create(:iiifmanifest, source_record: 'schmit:ark:/12345/testid2#subid"1"') }    
      
      context "prefix search" do
        let(:result1) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid1#')}
        let(:result2) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid2#')}
        let(:result3) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid\\2')}
        it "finds correct manifests" do
          expect(result1.map(&:id)).to match_array([manifest1.id,manifest2.id])
          expect(result2.map(&:id)).to match_array([manifest3.id])
          expect(result3.empty?).to eql(true)
        end
      end
      
      context "exact search" do
        let(:result1) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid1#subid\\1',false)}
        let(:result2) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid2#subid"1"',false)}
        let(:result3) { Trifle::IIIFManifest.find_from_source('schmit:ark:/12345/testid1#',false)}
        it "finds correct manifests" do
          expect(result1.map(&:id)).to match_array([manifest1.id])
          expect(result2.map(&:id)).to match_array([manifest3.id])
          expect(result3.empty?).to eql(true)
        end
      end
    end
  end
  
  describe "::all_in_collections" do
    let!(:root1) { FactoryGirl.create(:iiifcollection, ordered_members: [sub1, man1]) }
    let!(:sub1) { FactoryGirl.create(:iiifcollection, ordered_members: [man2])}
    let!(:root2) { FactoryGirl.create(:iiifcollection, ordered_members: [man3]) }
    let(:man1) { FactoryGirl.create(:iiifmanifest) }
    let(:man2) { FactoryGirl.create(:iiifmanifest) }
    let(:man3) { FactoryGirl.create(:iiifmanifest) }
    before { Trifle::IIIFManifest.all.each do |m| m.update_index end }
    let(:all) { Trifle::IIIFManifest.all_in_collection(root1) }
    it "returns all in specified collection" do
      expect(all.count).to eql(2)
      expect(all.map(&:id)).to match_array([man1.id,man2.id])
    end
  end  
  
  describe "id minting" do
    before { File.unlink('/tmp/test-minter-state_manifest') if File.exists?('/tmp/test-minter-state_manifest') }
    before { allow(Trifle).to receive(:config).and_return({'ark_naan' => '12345', 'identifier_template' => 't0.reeddeeddk', 'identifier_statefile' => '/tmp/test-minter-state'}) }
    let(:id) { manifest.assign_id }
    it "uses manifest minter" do
      expect(id).to start_with('t0m')
    end
  end
  
  describe "#inherited_logo" do
    let(:logo2) { 'http://www.example.com/logo2.png' }
    let(:manifest) { FactoryGirl.create(:iiifmanifest) }
    let(:collection) { 
      FactoryGirl.create(:iiifcollection).tap do |c| 
        c.ordered_members << manifest
        c.save
      end 
    }
    let(:parent) {
      FactoryGirl.create(:iiifcollection, logo: logo2).tap do |c| 
        c.ordered_members << collection
        c.save
      end
    }
    it "returns logo from parent" do
      parent # create by reference
      expect(manifest.inherited_logo).to eql(logo2)
    end
    it "returns nil if no parent" do
      expect(manifest.inherited_logo).to be_nil
    end
  end  
  
  describe "#to_millennium" do
    before { allow(DurhamRails::LibrarySystems::Millennium).to receive(:connection).and_return(mock_millennium)}
    let(:mock_millennium) { 
      double('mock_millennium').tap do |m| allow(m).to receive(:record).with('12345').and_return(mock_record) end
    }
    let(:mock_record) {
      double('mock_record').tap do |m| allow(m).to receive(:holdings).and_return([double('mock_holding',holding_id: 'test', call_no: 'testcallno')]) end
    }
    before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
    let(:manifest) { FactoryGirl.create(:iiifmanifest) } # need ark and id in manifest
    it "returns nil when source is not in millennium" do
      manifest.source_record = nil
      expect(manifest.to_millennium).to be_nil
      manifest.source_record = "schmit:test"
      expect(manifest.to_millennium).to be_nil
    end
    it "returns millennium records" do
      manifest.source_record = "millennium:12345#test"
      mil = manifest.to_millennium
      expect(mil['12345'][0].to_s).to eql("533    $8 1\\c $3 testcallno $a Digital image $c Durham University $5 UkDhU ")
      expect(mil['12345'][1].to_s).to eql("856 41 $8 1\\c $3 testcallno $u https://n2t.durham.ac.uk/ark:/12345/#{manifest.id}.html $y Online version $x Injected by Trifle ")
      manifest.digitisation_note = 'test digitisation note'
      mil = manifest.to_millennium
      expect(mil['12345'][0].to_s).to eql("533    $8 1\\c $3 testcallno $a Digital image $c Durham University $n test digitisation note $5 UkDhU ")
    end
  end
  
  describe "#to_millennium_all" do
    before { allow(Trifle::IIIFManifest).to receive(:ark_naan).and_return('12345') }
    before { allow(Trifle::IIIFCollection).to receive(:ark_naan).and_return('12345') }
    before { allow(Trifle::IIIFImage).to receive(:ark_naan).and_return('12345') }
    before { allow(DurhamRails::LibrarySystems::Millennium).to receive(:connection).and_return(mock_millennium)}
    let(:mock_millennium) { 
      double('mock_millennium').tap do |m| allow(m).to receive(:record).and_return(nil) end
    }
    let!(:manifest1) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:12345#test') }
    let!(:manifest2) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:67890') }
    let!(:manifest3) { FactoryGirl.create(:iiifmanifest, source_record: 'millennium:12345') }
    let!(:manifest4) { FactoryGirl.create(:iiifmanifest) }
    let!(:collection1) { FactoryGirl.create(:iiifcollection, source_record: 'millennium:12345#test') }
    let!(:collection2) { FactoryGirl.create(:iiifcollection, source_record: 'millennium:67890') }
    let!(:image1) { FactoryGirl.create(:iiifimage, :with_manifest, source_record: 'millennium:12345') }
    it "merges all from same source" do
      expect(Trifle::IIIFManifest).to receive(:reassign_marc_field_links).at_least(:once).and_call_original
      mil = manifest1.to_millennium_all
      records = mil['12345'].map(&:to_s)
      expect(records.count).to eql(8)
      expect(records.index("533    $8 1\\c $a Digital image $c Durham University $5 UkDhU ")).to be_present
      expect(records.index("533    $8 2\\c $a Digital image $c Durham University $5 UkDhU ")).to be_present
      expect(records.index("533    $8 3\\c $a Digital image $c Durham University $5 UkDhU ")).to be_present
      expect(records.index("533    $8 4\\c $a Digital image $c Durham University $5 UkDhU ")).to be_present
      
      expect(records.find do |r| r.match(/856 41 \$8 [1-4]\\c \$u https:\/\/n2t\.durham\.ac.uk\/ark:\/12345\/#{manifest1.id}\.html \$y Online version \$x Injected by Trifle /) end).to be_present
      expect(records.find do |r| r.match(/856 41 \$8 [1-4]\\c \$u https:\/\/n2t\.durham\.ac.uk\/ark:\/12345\/#{manifest3.id}\.html \$y Online version \$x Injected by Trifle /) end).to be_present
      expect(records.find do |r| r.match(/856 41 \$8 [1-4]\\c \$u https:\/\/n2t\.durham\.ac.uk\/ark:\/12345\/#{collection1.id}\.html \$y Online version \$x Injected by Trifle /) end).to be_present
      expect(records.find do |r| r.match(/856 41 \$8 [1-4]\\c \$u https:\/\/n2t\.durham\.ac.uk\/#{image1.local_ark}\.html \$y Online version \$x Injected by Trifle /) end).to be_present
    end
  end
  
  describe "::reassign_marc_field_links" do
    let(:existing_fields) {[
        MARC::ControlField.new('001'), # make sure control fields go through
        MARC::DataField.new('856', '4', '1', ['8', "1\\c"], ['z', 'Online version'], ['u', 'http://example.com/1']),
        MARC::DataField.new('533', nil, nil, ['8', "1\\c"], ['a', 'Digital image'], ['n', 'note 1'], ['5', 'UkDhU']),
        MARC::DataField.new('856', '4', '1', ['8', " 3.2\\c"], ['z', 'Online version'], ['u', 'http://example.com/2']),
        MARC::DataField.new('533', nil, nil, ['8', " 3.2\\c"], ['a', 'Digital image'], ['n', 'note 2'], ['5', 'UkDhU']),
      ]}
    let(:new_fields) {[
        MARC::DataField.new('856', '4', '1', ['8', "1\\c"], ['z', 'Online version'], ['u', 'http://example.com/3']),
        MARC::DataField.new('856', '4', '1', ['8', "2.3\\u"], ['z', 'Online version'], ['u', 'http://example.com/4']),
        MARC::DataField.new('533', nil, nil, ['8', "1\\c"], ['a', 'Digital image'], ['n', 'note 3'], ['5', 'UkDhU']),      
        MARC::DataField.new('533', nil, nil, ['8', "2.3\\u"], ['a', 'Digital image'], ['n', 'note 4'], ['5', 'UkDhU']),      
      ]}
    let(:reassigned) { Trifle::IIIFManifest.reassign_marc_field_links(existing_fields, new_fields).map(&:to_s) }
    it "assigns new link ids" do
      reassigned
      expect(reassigned).to eql([
        '856 41 $8 4\c $z Online version $u http://example.com/3 ',
        '856 41 $8 5.3\u $z Online version $u http://example.com/4 ',
        '533    $8 4\c $a Digital image $n note 3 $5 UkDhU ',
        '533    $8 5.3\u $a Digital image $n note 4 $5 UkDhU '
        ])
    end
  end
end
