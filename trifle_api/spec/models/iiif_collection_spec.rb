require 'shared/model_common'

RSpec.describe Trifle::API::IIIFCollection do

  let( :all_json_s ) {
    %q|{"resources":[
      {"id":"tajd472w44j","title":"Test title","identifier":["ark:/12345/tajd472w44j"],"description":"test description","licence":"All rights reserved","attribution":"part of test items","logo":"http://www.example.com/logo.png","keeper":"Test Keeper"},
      {"id":"tajd472w55j","title":"Test title 2","identifier":["ark:/12345/tajd472w55j"],"description":"test description","licence":"All rights reserved","attribution":"part of test items"}],"page":1,"total_pages":1}|      
  }
  let( :sub_json_s ) { %q|{"id":"tajd472w66j","title":"Test title 3","identifier":["ark:/12345/tajd472w66j"],"description":"test description","licence":"All rights reserved","attribution":"part of test items"}| }
  let( :manifest_json_s ) { %q|{"id":"tajd472w77j","title":"Test manifest","identifier":["ark:/12345/tajd472w77j"],"description":"test description","licence":"All rights reserved","attribution":"part of test items","logo":"http://www.example.com/logo.png","keeper":"Test Keeper"}| }
  let( :json ) { {"id" => "tajd472w44j","title" => "Test title","identifier" => ["ark:/12345/tajd472w44j"],"description" => "test description","licence" => "All rights reserved", "attribution" => "part of test items", "logo" => "http://www.example.com/logo.png", "keeper" => "Test Keeper", "parent_id" => "dummy_collection_id"} }
  let( :collection ) { Trifle::API::IIIFCollection.from_json(json) }
  
  it_behaves_like "model_common"

  describe "#parent" do
    let( :parent_collection ) { Trifle::API::IIIFCollection.new }

    it "finds the parent" do
      allow(Trifle::API::IIIFCollection).to receive(:find).with('dummy_collection_id').and_return(parent_collection)
      expect(collection.parent).to eql(parent_collection)
    end

    it "raises when parent is not found" do
      allow(Trifle::API::IIIFCollection).to receive(:find).with('dummy_collection_id') { raise Trifle::API::FetchError }
      expect { collection.parent } .to raise_error(Trifle::API::FetchError)
    end

    it "returns nil when parent_id is nil" do
      json['parent_id'] = nil
      expect(collection.parent).to be_nil
    end
  end

  describe "all" do
    it "parses the response" do
      expect(Trifle::API::IIIFCollection).to receive(:get).and_return(OpenStruct.new(body: all_json_s, code: 200))
      resp = Trifle::API::IIIFCollection.all
      expect(resp).to be_a Array
      expect(resp.size).to eql 2
      resp.each do |repo|
        expect(repo).to be_a Trifle::API::IIIFCollection
      end
    end
  end
  
  describe ".all_in_collection" do
    it "parses the response" do
      expect(Trifle::API::IIIFCollection).to receive(:get).with("/collection/#{collection.id}.json?full_collection_list=1").and_return(OpenStruct.new(body: all_json_s, code: 200))
      resp = Trifle::API::IIIFCollection.all_in_collection(collection)
      expect(resp).to be_a Array
      expect(resp.size).to eql 2
      resp.each do |collection|
        expect(collection).to be_a Trifle::API::IIIFCollection
      end
    end
  end
  
  describe "#sub_collections" do
    context "with a fully feched resource" do
      let(:collection) { Trifle::API::IIIFCollection.from_json(json.merge('sub_collections' => [JSON.parse(sub_json_s)])) }
      it "returns sub_collections without fetching again" do
        expect(collection).not_to receive(:fetch)
        expect(collection.sub_collections.count).to eql(1)
        expect(collection.sub_collections.first).to be_a(Trifle::API::IIIFCollection)
        expect(collection.sub_collections.first.title).to eql('Test title 3')
      end
    end
    context "with a stub resource" do
      it "fetches and returns sub_collections" do
        expect(collection).to receive(:local_mode?).and_return(false)
        expect(Trifle::API::IIIFCollection).to receive(:get).and_return(OpenStruct.new(body: json.merge('sub_collections' => [JSON.parse(sub_json_s)]).to_json, code: 200))
        expect(collection.sub_collections.count).to eql(1)
        expect(collection.sub_collections.first).to be_a(Trifle::API::IIIFCollection)
        expect(collection.sub_collections.first.title).to eql('Test title 3')
      end
    end
  end
  
  describe "#manifests" do
    context "with a fully feched resource" do
      let(:collection) { Trifle::API::IIIFCollection.from_json(json.merge('manifests' => [JSON.parse(manifest_json_s)])) }
      it "returns sub_collections without fetching again" do
        expect(collection).not_to receive(:fetch)
        expect(collection.manifests.count).to eql(1)
        expect(collection.manifests.first).to be_a(Trifle::API::IIIFManifest)
        expect(collection.manifests.first.title).to eql('Test manifest')
      end
    end
    context "with a stub resource" do
      it "fetches and returns sub_collections" do
        expect(collection).to receive(:local_mode?).and_return(false)
        expect(Trifle::API::IIIFCollection).to receive(:get).and_return(OpenStruct.new(body: json.merge('manifests' => [JSON.parse(manifest_json_s)]).to_json, code: 200))
        expect(collection.manifests.count).to eql(1)
        expect(collection.manifests.first).to be_a(Trifle::API::IIIFManifest)
        expect(collection.manifests.first.title).to eql('Test manifest')
      end
    end
  end

  describe "#as_json" do
    it "adds attributes to json" do
      json = collection.as_json
      expect(json['identifier']).to eql ['ark:/12345/tajd472w44j']
      expect(json['description']).to eql('test description')
      expect(json['licence']).to eql('All rights reserved')      
      expect(json['attribution']).to eql('part of test items')
      expect(json['logo']).to eql('http://www.example.com/logo.png')
      expect(json['keeper']).to eql('Test Keeper')
      expect(json['parent_id']).to eql('dummy_collection_id')
    end
  end

  describe "#from_json" do
    it "parses everything" do
      expect(collection.identifier).to eql ['ark:/12345/tajd472w44j']
      expect(collection.description).to eql('test description')
      expect(collection.licence).to eql('All rights reserved')      
      expect(collection.attribution).to eql('part of test items')
      expect(collection.logo).to eql("http://www.example.com/logo.png")
      expect(collection.keeper).to eql('Test Keeper')
      expect(collection.parent_id).to eql('dummy_collection_id')
    end
  end

  context "with local mode" do
    let(:collection_id) { 'tajd472w44j' }
    before { allow(Trifle::API::IIIFCollection).to receive(:local_mode?).and_return(true) }
    before {
      Trifle.send(:const_set, :IIIFCollection, double('collection_class'))
      allow(Trifle::API::IIIFCollection).to receive(:local_class).and_return(Trifle::IIIFCollection)
    }
    after {
      Trifle.send(:remove_const,:IIIFCollection)
    }
    describe ".all_in_collection_local" do
      let(:collection_mock) { double('collection', id: 'colid') }
      let(:local_collection_mock) { double('local collection') }
      let(:local_sub_collection_mock) { double('local sub collection', as_json: json) }
      it "gets all in collection" do
        expect(Trifle::IIIFCollection).to receive(:find).with('colid').and_return(local_collection_mock)
        expect(Trifle::IIIFCollection).to receive(:all_in_collection).with(local_collection_mock).and_return([local_sub_collection_mock])
        resp = Trifle::API::IIIFCollection.all_in_collection(collection_mock)
        expect(resp).to be_a(Array)
        expect(resp.count).to eql(1)
        expect(resp.first).to be_a Trifle::API::IIIFCollection
        expect(resp.first.id).to eql(collection_id)
      end
    end
  end
end
