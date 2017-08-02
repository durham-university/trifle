require 'shared/model_common'

RSpec.describe Trifle::API::IIIFImage do

  let( :all_json_s ) {
    %q|{"resources":[
      {"id":"tajd472w44j","title":"Test title","identifier":["ark:/12345/t1mabc123def/tajd472w44j"],"description":"test description","width":"1000","height":"2000","image_location":"test/12345/abcd.jp2","image_source":"testsource:12345","source_record":"testrecord:12345"},
      {"id":"tajd472w55j","title":"Test title 2","identifier":["ark:/12345/t1mabc123def/tajd472w55j"],"description":"test description","width":"1000","height":"2000","image_location":"test/12345/abcd.jp2","image_source":"testsource:12345","source_record":"testrecord:12345"},
      {"id":"tajd472w66j","title":"Test title 3","identifier":["ark:/12345/t1mabc456ghi/tajd472w66j"],"description":"test description","width":"1000","height":"2000","image_location":"test/12345/abcd.jp2","image_source":"testsource:12345","source_record":"testrecord:12345"}],"page":1,"total_pages":1}|      
  }
  let( :json ) { {"id" => "tajd472w44j","title" => "Test title","identifier" => ["ark:/12345/t1mabc123def/tajd472w44j"],"description" => "test description","width" => "1000","height" => "2000","image_location" => "test/12345/abcd.jp2","image_source" => "testsource:12345","source_record" => "testrecord:12345", "parent_id" => "dummy_manifest_id"} }
  let( :image ) { Trifle::API::IIIFImage.from_json(json) }
#  let( :manifest ) { Trifle::API::IIIFManifest.from_json('id' => 'manid', 'title' => 'test manifest') }

  it_behaves_like "model_common"
  
  describe "#parent" do
    let( :parent_manifest ) { Trifle::API::IIIFManifest.new }

    it "finds the parent" do
      allow(Trifle::API::IIIFManifest).to receive(:find).with('dummy_manifest_id').and_return(parent_manifest)
      expect(image.parent).to eql(parent_manifest)
    end

    it "raises when parent is not found" do
      allow(Trifle::API::IIIFManifest).to receive(:find).with('dummy_manifest_id') { raise Trifle::API::FetchError }
      expect { image.parent } .to raise_error(Trifle::API::FetchError)
    end

    it "returns nil when parent_id is nil" do
      json['parent_id'] = nil
      expect(image.parent).to be_nil
    end
  end  

  describe ".all_in_source" do
    it "parses the response" do
      expect(Trifle::API::IIIFImage).to receive(:get).with("/image.json?in_source=moo%23baa&per_page=all").and_return(OpenStruct.new(body: all_json_s, code: 200))
      resp = Trifle::API::IIIFImage.all_in_source('moo#baa')
      expect(resp).to be_a Array
      expect(resp.size).to eql 3
      resp.each do |repo|
        expect(repo).to be_a Trifle::API::IIIFImage
      end
    end
  end

  describe "#as_json" do
    it "adds attributes to json" do
      json = image.as_json
      expect(json['identifier']).to eql ['ark:/12345/t1mabc123def/tajd472w44j']
      expect(json['source_record']).to eql("testrecord:12345")
      expect(json['description']).to eql('test description')
      expect(json['parent_id']).to eql('dummy_manifest_id')
      expect(json['width']).to eql('1000')
      expect(json['height']).to eql('2000')
      expect(json['image_location']).to eql("test/12345/abcd.jp2")
      expect(json['image_source']).to eql("testsource:12345")
    end
  end

  describe "#from_json" do
    it "parses everything" do
      expect(image.identifier).to eql ['ark:/12345/t1mabc123def/tajd472w44j']
      expect(image.source_record).to eql("testrecord:12345")
      expect(image.description).to eql('test description')
      expect(image.parent_id).to eql('dummy_manifest_id')
      expect(image.width).to eql('1000')
      expect(image.height).to eql('2000')
      expect(image.image_location).to eql('test/12345/abcd.jp2')
      expect(image.image_source).to eql('testsource:12345')
    end
  end
end
