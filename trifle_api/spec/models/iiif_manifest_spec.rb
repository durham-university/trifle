require 'shared/model_common'

RSpec.describe Trifle::API::IIIFManifest do

  let( :all_json_s ) {
    %q|{"resources":[
      {"id":"tajd472w44j","title":"Test title","image_container_location":"testimages","identifier":["ark:/12345/tajd472w44j"],"date_published":"Xth century","author":["various authors"],"description":"test description","licence":"All rights reserved","attribution":"part of test items"},
      {"id":"tajd472w55j","title":"Test title 2","image_container_location":"testimages2","identifier":["ark:/12345/tajd472w55j"],"date_published":"Xth century","author":["various authors"],"description":"test description","licence":"All rights reserved","attribution":"part of test items"},
      {"id":"tajd472w66j","title":"Test title 3","image_container_location":"testimages3","identifier":["ark:/12345/tajd472w66j"],"date_published":"Xth century","author":["various authors"],"description":"test description","licence":"All rights reserved","attribution":"part of test items"}],"page":1,"total_pages":1}|      
  }
  let( :json ) { {"id" => "tajd472w44j","title" => "Test title","image_container_location" => "testimages","source_record" => "ark:/12345/test/testid#subid", "identifier" => ["ark:/12345/tajd472w44j"], "date_published" => "Xth century", "author" => ["various authors"], "description" => "test description", "licence" => "All rights reserved", "attribution" => "part of test items", "parent_id" => "dummy_collection_id"} }
  let( :manifest ) { Trifle::API::IIIFManifest.from_json(json) }
  let( :collection ) { Trifle::API::IIIFCollection.from_json('id' => 'colid', 'title' => 'test collection') }
  let( :deposit_items ) { ['http://localhost/dummy1','http://localhost/dummy2'] }

  it_behaves_like "model_common"
  
  describe "#parent" do
    let( :parent_collection ) { Trifle::API::IIIFCollection.new }

    it "finds the parent" do
      allow(Trifle::API::IIIFCollection).to receive(:find).with('dummy_collection_id').and_return(parent_collection)
      expect(manifest.parent).to eql(parent_collection)
    end

    it "raises when parent is not found" do
      allow(Trifle::API::IIIFCollection).to receive(:find).with('dummy_collection_id') { raise Trifle::API::FetchError }
      expect { manifest.parent } .to raise_error(Trifle::API::FetchError)
    end

    it "returns nil when parent_id is nil" do
      json['parent_id'] = nil
      expect(manifest.parent).to be_nil
    end
  end  

  describe ".all" do
    it "parses the response" do
      expect(Trifle::API::IIIFManifest).to receive(:get).with('/iiif_manifests.json?per_page=1000').and_return(OpenStruct.new(body: all_json_s, code: 200))
      resp = Trifle::API::IIIFManifest.all
      expect(resp).to be_a Array
      expect(resp.size).to eql 3
      resp.each do |manifest|
        expect(manifest).to be_a Trifle::API::IIIFManifest
      end
    end
  end
  
  describe ".all_in_collection" do
    it "parses the response" do
      expect(Trifle::API::IIIFManifest).to receive(:get).with("/iiif_collections/#{collection.id}.json?full_manifest_list=1").and_return(OpenStruct.new(body: all_json_s, code: 200))
      resp = Trifle::API::IIIFManifest.all_in_collection(collection)
      expect(resp).to be_a Array
      expect(resp.size).to eql 3
      resp.each do |repo|
        expect(repo).to be_a Trifle::API::IIIFManifest
      end
    end
  end
  
  describe ".all_in_source" do
    it "parses the response" do
      expect(Trifle::API::IIIFManifest).to receive(:get).with("/iiif_manifests.json?in_source=moo%23baa&per_page=1000&api_debug=true").and_return(OpenStruct.new(body: all_json_s, code: 200))
      resp = Trifle::API::IIIFManifest.all_in_source('moo#baa')
      expect(resp).to be_a Array
      expect(resp.size).to eql 3
      resp.each do |repo|
        expect(repo).to be_a Trifle::API::IIIFManifest
      end
    end
  end

  describe "#as_json" do
    it "adds attributes to json" do
      json = manifest.as_json
      expect(json['image_container_location']).to eql 'testimages'
      expect(json['identifier']).to eql ['ark:/12345/tajd472w44j']
      expect(json['source_record']).to eql("ark:/12345/test/testid#subid")
      expect(json['date_published']).to eql('Xth century')
      expect(json['author']).to eql(['various authors'])
      expect(json['description']).to eql('test description')
      expect(json['licence']).to eql('All rights reserved')      
      expect(json['attribution']).to eql('part of test items')
      expect(json['parent_id']).to eql('dummy_collection_id')
    end
  end

  describe "#from_json" do
    it "parses everything" do
      expect(manifest.image_container_location).to eql 'testimages'
      expect(manifest.identifier).to eql ['ark:/12345/tajd472w44j']
      expect(manifest.source_record).to eql("ark:/12345/test/testid#subid")
      expect(manifest.date_published).to eql('Xth century')
      expect(manifest.author).to eql(['various authors'])
      expect(manifest.description).to eql('test description')
      expect(manifest.licence).to eql('All rights reserved')      
      expect(manifest.attribution).to eql('part of test items')
      expect(manifest.parent_id).to eql('dummy_collection_id')
    end
  end

  describe ".deposit_new" do
    let( :parent ) { collection }
    let( :manifest_metadata ) { { title: 'test title', description: 'test description' } }
    let( :response ) { { status: 'ok', resource: json }.to_json }
    let( :response_code ) { 200 }
    before {
      expect(Trifle::API::IIIFManifest).to receive(:post) { |url,params|
        expect(url).to eql "/iiif_collections/#{parent.id}/iiif_manifests/deposit.json"
        query = params[:query]
        expect(query[:deposit_items]).to eql(deposit_items)
        expect(query[:iiif_manifest]).to eql(manifest_metadata)
        OpenStruct.new(body: response, code: response_code)
      }
    }
    it "deposits items" do
      resp = Trifle::API::IIIFManifest.deposit_new(parent, deposit_items, manifest_metadata)
      expect(resp[:resource]).to be_a Trifle::API::IIIFManifest
      expect(resp[:status]).to eql 'ok'
    end
    context "with error" do
      let( :response ) { { status: 'error', message: 'test message' }.to_json }
      it "handles errors" do
        resp = Trifle::API::IIIFManifest.deposit_new(parent, deposit_items, manifest_metadata)
        expect(resp[:status]).to eql 'error'
        expect(resp[:message]).to include 'test message'
      end
    end
  end
  
  describe ".deposit_into" do
    let( :response ) { { status: 'ok', resource: json }.to_json }
    let( :response_code ) { 200 }
    before {
      expect(Trifle::API::IIIFManifest).to receive(:post) { |url,params|
        expect(url).to eql "/iiif_manifests/tajd472w44j/deposit.json"
        query = params[:query]
        expect(query[:'deposit_items']).to eql(deposit_items)
        OpenStruct.new(body: response, code: response_code)
      }
    }
    it "deposits items" do
      resp = Trifle::API::IIIFManifest.deposit_into(manifest, deposit_items)
      expect(resp[:resource]).to be_a Trifle::API::IIIFManifest
      expect(resp[:status]).to eql 'ok'
    end
    context "with error" do
      let( :response ) { { status: 'error', message: 'test message' }.to_json }
      it "handles errors" do
        resp = Trifle::API::IIIFManifest.deposit_into(manifest, deposit_items)
        expect(resp[:status]).to eql 'error'
        expect(resp[:message]).to include 'test message'
      end
    end
  end  
  
  context "with local mode" do
    let(:manifest_id) { 'tajd472w44j' }
    let(:local_collection_mock) { double('local_collection_mock', ordered_members: collection_members_mock) }
    let(:collection_members_mock) { double('local_collection_members_mock') }
    let(:local_manifest_mock) { double('local_manifest_mock', as_json: json) }
    let(:new_manifest_mock) { double('new_manifest_mock', as_json: json) }
    let(:job_mock) { double('job_mock') }
    let( :parent ) { collection }
    before { allow(Trifle::API::IIIFManifest).to receive(:local_mode?).and_return(true) }
    before {
      Trifle.send(:const_set, :IIIFManifest, double('manifest_class'))
      Trifle.send(:const_set, :IIIFCollection, double('collection_class'))
      Trifle.send(:const_set, :DepositJob, double('job_class'))
      allow(Trifle::IIIFCollection).to receive(:find).with(parent.id).and_return(local_collection_mock)
      allow(Trifle::IIIFManifest).to receive(:find).with(manifest_id).and_return(local_manifest_mock)
      allow(Trifle::IIIFManifest).to receive(:new).and_return(new_manifest_mock)
      allow(Trifle::API::IIIFManifest).to receive(:local_class).and_return(Trifle::IIIFManifest)
      allow(Trifle::API::IIIFCollection).to receive(:local_class).and_return(Trifle::IIIFCollection)
    }
    after {
      Trifle.send(:remove_const,:IIIFManifest)
      Trifle.send(:remove_const,:IIIFCollection)
      Trifle.send(:remove_const,:DepositJob)
    }
    describe ".deposit_new_local" do
      let(:manifest_metadata ) { { title: 'test title', description: 'test description' } }
      it "deposits items" do
        expect(new_manifest_mock).to receive(:source_record).at_least(:once).and_return("test:ark:/12345/testid")
        expect(new_manifest_mock).to receive(:refresh_from_source).and_return(true)
        expect(new_manifest_mock).to receive(:default_container_location!)
        expect(new_manifest_mock).to receive(:save).and_return(true)
        expect(new_manifest_mock).to receive(:attributes=) do |val|
          expect(val).to eql(manifest_metadata)
        end
        expect(local_collection_mock).to receive(:save).and_return(true)
        expect(collection_members_mock).to receive(:<<).with(new_manifest_mock)
        expect(Trifle::DepositJob).to receive(:new)
          .with(hash_including(resource: new_manifest_mock, deposit_items: deposit_items))
          .and_return(job_mock)
        expect(job_mock).to receive(:queue_job)
        
        resp = Trifle::API::IIIFManifest.deposit_new(parent, deposit_items,manifest_metadata)
        expect(resp[:resource]).to be_a Trifle::API::IIIFManifest
        expect(resp[:status]).to eql 'ok'
      end
    end    
    describe ".deposit_into_local" do
      it "deposits items" do
        expect(Trifle::DepositJob).to receive(:new)
          .with(hash_including(resource: local_manifest_mock, deposit_items: deposit_items))
          .and_return(job_mock)
        expect(job_mock).to receive(:queue_job)
        
        resp = Trifle::API::IIIFManifest.deposit_into(manifest, deposit_items)
        expect(resp[:resource]).to be_a Trifle::API::IIIFManifest
        expect(resp[:status]).to eql 'ok'
      end
    end
    describe ".all_in_collection_local" do
      let(:collection_mock) { double('collection', id: 'colid') }
      let(:local_collection_mock) { double('local collection') }
      it "gets all in collection" do
        expect(Trifle::IIIFCollection).to receive(:find).with('colid').and_return(local_collection_mock)
        expect(Trifle::IIIFManifest).to receive(:all_in_collection).with(local_collection_mock).and_return([local_manifest_mock])
        resp = Trifle::API::IIIFManifest.all_in_collection(collection_mock)
        expect(resp).to be_a(Array)
        expect(resp.count).to eql(1)
        expect(resp.first).to be_a Trifle::API::IIIFManifest
        expect(resp.first.id).to eql(manifest_id)
      end
    end
  end
end
